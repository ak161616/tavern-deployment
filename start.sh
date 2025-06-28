#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 【已移除】我们不再需要在运行时进行任何克隆、安装和编译！---

# --- 步骤 1: 【最终决定性修复】检查由 Configmap 挂载的配置文件 ---
CONFIG_FILE_PATH="/home/node/app/config.yaml"
if [ ! -f "$CONFIG_FILE_PATH" ]; then
    echo "[Config] CRITICAL: Config file not found. Please ensure the Configmap is set up correctly."
    exit 1
fi

# --- 步骤 2: 配置并恢复云存档 ---
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    mkdir -p /home/node/app/data
    cd /home/node/app/data
    /opt/scripts/config.sh "$REPO_URL" "$GITHUB_TOKEN"
    /opt/scripts/load.sh
fi

# --- 步骤 3: 启动后台自动保存任务 ---
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    run_auto_save_in_background() {
        cd /home/node/app/data
        while true; do
            sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
            /opt/scripts/save.sh
        done
    }
    run_auto_save_in_background &
fi

# --- 步骤 4: 启动 SillyTavern 主程序 ---
echo "[Main] All setup complete. Starting pre-compiled SillyTavern..."
cd /home/node/app

# 直接启动，不再需要任何内存参数，因为它已经编译好了
# --host 0.0.0.0 是为了保险起见，确保它能被平台访问
exec tini -- node server.js --host 0.0.0.0
