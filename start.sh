#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 步骤 1: 【最终决定性修复】检查由 Configmap 挂载的配置文件 ---
# 我们不再检查环境变量，而是直接检查配置文件是否真实地存在于它应该在的位置
CONFIG_FILE_PATH="/home/node/app/config.yaml"
echo "[Config] Checking for configuration file provided by Configmap..."

if [ -f "$CONFIG_FILE_PATH" ]; then
    echo "[Config] SUCCESS: Found config file at $CONFIG_FILE_PATH."
    # 文件已经由平台为我们准备好了，我们不需要再做任何事！
else
    echo "[Config] CRITICAL: Config file not found at $CONFIG_FILE_PATH. Please ensure the Configmap is set up correctly in the Claw Cloud dashboard."
    exit 1
fi


# --- 步骤 2: 配置并恢复云存档 ---
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "[Cloud Save] Config detected, initializing..."
    # 确保 data 目录存在，以防万一
    mkdir -p /home/node/app/data
    cd /home/node/app/data
    /opt/scripts/config.sh "$REPO_URL" "$GITHUB_TOKEN"
    /opt/scripts/load.sh
else
    echo "[Cloud Save] Warning: Cloud save secrets not found, skipping cloud save setup."
fi


# --- 步骤 3: 启动后台自动保存任务 ---
# 只有在云存档配置存在时，才启动后台任务
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "[Auto-Save] Starting the auto-save process in the background..."
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


# --- 步骤 4: 启动 SillyTavern 主程序 ---
echo "[Main] All setup complete. Starting SillyTavern..."
cd /home/node/app
# 我们将不再需要为这个进程增加内存，因为编译已经在GitHub Actions完成
# 但为了以防万一，我们保留这个参数，它没有任何坏处
exec tini -- node --max-old-space-size=4096 server.js --host 0.0.0.0
