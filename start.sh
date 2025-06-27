#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 步骤 1: 动态创建 config.yaml 文件 ---
if [ -n "$CONFIG_YAML" ]; then
    echo "[Config] Found CONFIG_YAML secret. Creating config.yaml file..."
    # 确保我们在正确的目录下
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

# --- 步骤 3: 【最终决定性修复】启动主程序并智能地监控 ---
echo "[Main] All setup complete. Starting SillyTavern as a background daemon..."
cd /home/node/app

# 定义一个日志文件，用于监控主程序的状态
SERVER_LOG="/tmp/server.log"
touch "$SERVER_LOG"

# 将主程序作为后台进程启动，并将它的所有输出都重定向到日志文件中
# 这让 tini 能够正确地作为守护进程运行
tini -- node --max-old-space-size=4096 server.js --host 0.0.0.0 > "$SERVER_LOG" 2>&1 &

# 获取主程序的进程ID (PID)
NODE_PID=$!
echo "[Main] SillyTavern started in the background with PID: $NODE_PID"

# --- 步骤 4: 监控日志，等待主程序就绪 ---
echo "[Monitor] Waiting for server to be ready... (Monitoring log: $SERVER_LOG)"
# 使用 tail -f 持续监控日志文件，直到我们看到成功启动的信号
# 使用 --pid=$NODE_PID 确保如果主进程死亡，tail也会退出
# 使用 timeout 确保我们不会永远等待下去（例如15分钟）
timeout 900s tail -f --pid=$NODE_PID "$SERVER_LOG" | while IFS= read -r line; do
    # 实时打印主程序的日志，方便我们观察
    echo "$line"
    # 检查成功启动的信号
    if echo "$line" | grep -q "is listening on IPv4: 0.0.0.0:8000"; then
        echo "[Monitor] SUCCESS! Server is confirmed to be up and running!"
        # 杀死 tail 进程，退出循环
        pkill -P $$ tail
    fi
done

# --- 步骤 5: 启动后台自动保存任务 ---
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "[Auto-Save] Server is ready. It is now safe to start the auto-save process."
    # 一个在后台运行自动保存的函数
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
# 使用 wait 命令，让这个主脚本进程安静地、忠诚地等待主程序（$NODE_PID）的结束
# 这确保了容器不会提前退出，并且能正确响应平台的停止信号
wait $NODE_PID
