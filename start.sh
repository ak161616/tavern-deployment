#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 一个在后台运行自动保存的函数 ---
run_auto_save_in_background() {
    while true; do
        echo "[Auto-Save] Sleeping for ${AUTOSAVE_INTERVAL:-30} minutes..."
        sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
        
        echo "[Auto-Save] Waking up and saving data..."
        /opt/scripts/save.sh
        echo "[Auto-Save] Save process finished."
    done
}

# 定义脚本目录
SCRIPTS_DIR="/opt/scripts"

# --- 步骤 1: 动态创建 config.yaml 文件 ---
if [ -n "$CONFIG_YAML" ]; then
    echo "[Config] Found CONFIG_YAML secret. Creating config.yaml file..."
    cd /home/node/app
    echo "$CONFIG_YAML" > ./config.yaml
else
    echo "[Config] CRITICAL: CONFIG_YAML secret not found."
    exit 1
fi

# --- 步骤 2: 配置并恢复云存档 (后台任务) ---
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "[Cloud Save] Config detected, initializing..."
    mkdir -p /home/node/app/data
    cd /home/node/app/data
    /opt/scripts/config.sh "$REPO_URL" "$GITHUB_TOKEN"
    /opt/scripts/load.sh
    run_auto_save_in_background &
    echo "[Cloud Save] Auto-save process started in the background."
else
    echo "[Cloud Save] Warning: Secrets not found, skipping cloud save setup."
fi

# --- 步骤 3: 启动 SillyTavern 主程序 ---
echo "[Main] All setup complete. Starting pre-compiled SillyTavern..."
cd /home/node/app

# 【最终关键修复】在启动时，用命令行参数明确指定监听地址为 0.0.0.0
# 这将覆盖任何默认行为，并允许 Koyeb 的健康检查成功通过
exec tini -- node server.js --host 0.0.0.0
