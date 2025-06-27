#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# 【最终决定性修复】将所有逻辑都封装在 tini 执行的 sh -c '...' 内部
# 这确保了所有的变量定义和使用，都在同一个 shell 环境（作用域）中
# 从而彻底解决了 "grep: : No such file or directory" 的问题

exec tini -- sh -c '
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

    # --- 步骤 3: 启动主程序并使用最可靠的方式进行监控 ---
    echo "[Main] All setup complete. Starting SillyTavern as a background daemon..."
    cd /home/node/app

    # 定义日志文件，现在它和使用者在同一个作用域内
    SERVER_LOG="/tmp/server.log"
    touch "$SERVER_LOG"

    # 将主程序作为后台进程启动
    node --max-old-space-size=4096 server.js --host 0.0.0.0 > "$SERVER_LOG" 2>&1 &
    
    # 获取主程序的进程ID
    NODE_PID=$!
    echo "[Main] SillyTavern started in the background with PID: $NODE_PID"

    # --- 步骤 4: 【最可靠的监控循环】---
    echo "[Monitor] Waiting for server to be ready..."
    TIMEOUT=900 
    while [ $TIMEOUT -gt 0 ]; do
        if grep -q "is listening on IPv4: 0.0.0.0:8000" "$SERVER_LOG"; then
            echo "[Monitor] SUCCESS! Server is confirmed to be up and running!"
            break
        fi
        sleep 2
        TIMEOUT=$((TIMEOUT-2))
    done

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
    tail -f "$SERVER_LOG" &
    wait $NODE_PID
'
