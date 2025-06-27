#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 步骤 1: 动态创建 config.yaml 文件 ---
if [ -n "$CONFIG_YAML" ]; then
    echo "[Config] Found CONFIG_YAML secret. Creating config.yaml file..."
    cd /home/node/app
    echo "$CONFIG_YAML" > ./config.yaml
else
    echo "[Config] CRITICAL: CONFIG_YAML secret not found."
    exit 1
fi

# --- 步骤 2: 配置并恢复云存档 ---
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "[Cloud Save] Config detected, initializing..."
    mkdir -p /home/node/app/data
    cd /home/node/app/data
    /opt/scripts/config.sh "$REPO_URL" "$GITHUB_TOKEN"
    /opt/scripts/load.sh
else
    echo "[Cloud Save] Warning: Secrets not found, skipping cloud save setup."
fi

# --- 步骤 3: 【最终决定性修复】启动主程序并使用最可靠的方式进行监控 ---
echo "[Main] All setup complete. Starting SillyTavern as a background daemon..."
cd /home/node/app

SERVER_LOG="/tmp/server.log"
touch "$SERVER_LOG"

# 启动主程序，并将输出重定向到日志文件。tini 会成为 PID 1。
# exec 是关键，它会用 tini 替换当前的 shell 进程
exec tini -- sh -c '
    # 将主程序作为后台任务启动
    node --max-old-space-size=4096 server.js --host 0.0.0.0 &
    
    # 获取主程序的进程ID
    NODE_PID=$!
    echo "[Main] SillyTavern started in the background with PID: $NODE_PID"

    # --- 步骤 4: 【最可靠的监控循环】---
    echo "[Monitor] Waiting for server to be ready..."
    # 我们设置一个最长15分钟的超时，以防万一
    TIMEOUT=900 
    while [ $TIMEOUT -gt 0 ]; do
        # 我们用 grep -q 来安静地检查日志文件中是否包含成功启动的信号
        if grep -q "is listening on IPv4: 0.0.0.0:8000" "$SERVER_LOG"; then
            echo "[Monitor] SUCCESS! Server is confirmed to be up and running!"
            # 一旦成功，就退出这个监控循环
            break
        fi
        # 如果没找到，就等待2秒，然后继续检查
        sleep 2
        TIMEOUT=$((TIMEOUT-2))
    done

    # 如果超时了，说明主程序启动失败，打印错误并退出
    if [ $TIMEOUT -le 0 ]; then
        echo "[Monitor] ERROR: Timed out waiting for server to start. Dumping log..."
        cat "$SERVER_LOG"
        exit 1
    fi
    
    # --- 步骤 5: 启动后台自动保存任务 ---
    if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
        echo "[Auto-Save] Server is ready. It is now safe to start the auto-save process."
        run_auto_save_in_background() {
            cd /home/node/app/data
            while true; do
                echo "[Auto-Save] Sleeping for ${AUTOSAVE_INTERVAL:-30} minutes..."
                sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
                /opt/scripts/save.sh
            done
        }
        run_auto_save_in_background &
    fi

    # --- 步骤 6: 成为最终的“守护者” ---
    echo "[Guardian] Handing off control to main process. Tini will now reap zombies."
    # 实时打印主程序的日志，方便在Koyeb界面上观察
    tail -f "$SERVER_LOG" &
    # 等待主程序进程结束
    wait $NODE_PID
'
