#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 一个在后台运行自动保存的函数 ---
run_auto_save_in_background() {
    # 确保我们在正确的目录下执行git命令
    cd /home/node/app/data
    while true; do
        echo "[Auto-Save] Sleeping for ${AUTOSAVE_INTERVAL:-30} minutes..."
        sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
        
        echo "[Auto-Save] Waking up and saving data..."
        /opt/scripts/save.sh
        echo "[Auto-Save] Save process finished."
    done
}

# --- 步骤 1: 动态创建 config.yaml 文件 ---
if [ -n "$CONFIG_YAML" ]; then
    echo "[Config] Found CONFIG_YAML secret. Creating config.yaml file..."
    cd /home/node/app
    echo "$CONFIG_YAML" > ./config.yaml
else
    echo "[Config] CRITICAL: CONFIG_YAML secret not found."
    exit 1
fi

# --- 步骤 2: 配置并恢复云存档 (仅加载，不启动后台任务) ---
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "[Cloud Save] Config detected, initializing..."
    mkdir -p /home/node/app/data
    cd /home/node/app/data
    /opt/scripts/config.sh "$REPO_URL" "$GITHUB_TOKEN"
    /opt/scripts/load.sh
else
    echo "[Cloud Save] Warning: Secrets not found, skipping cloud save setup."
fi

# --- 步骤 3: 【最终决定性修复】启动主程序，并智能地等待其就绪后再启动后台任务 ---
echo "[Main] All setup complete. Starting SillyTavern and waiting for ready signal..."
cd /home/node/app

# 使用管道，将主程序的输出传递给一个处理循环
# exec 会将shell进程替换为tini，这是最后一个命令，确保信号能正确传递
exec tini -- node --max-old-space-size=4096 server.js --host 0.0.0.0 | while IFS= read -r line; do
    # 将主程序的每一行日志都打印出来，方便我们观察
    echo "$line"
    
    # 检查日志中是否包含了“已就绪”的关键信息
    if echo "$line" | grep -q "is listening on IPv4: 0.0.0.0:8000"; then
        echo "[Smart Starter] Server is confirmed to be up and running!"
        
        # 只有在主程序确认就绪后，才安全地启动后台自动保存任务
        if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
            echo "[Smart Starter] It is now safe to start the auto-save process."
            run_auto_save_in_background &
        fi
    fi
done
