#!/bin/sh
set -e

# --- 步骤 1: 动态克隆并安装 SillyTavern ---
echo "[Deployment] Starting deployment process..."
if [ -z "$(ls -A /home/node/app)" ]; then
    echo "[Deployment] App directory is empty. Cloning SillyTavern..."
    git clone -b staging --depth 1 https://github.com/SillyTavern/SillyTavern.git .
    echo "[Deployment] Installing npm dependencies..."
    npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force
    echo "[Deployment] Compiling frontend libraries..."
    if [ -f "./docker/build-lib.js" ]; then
        node "./docker/build-lib.js";
    elif [ -f "./build-lib.js" ]; then
        node "./build-lib.js";
    fi
else
    echo "[Deployment] App directory already populated. Skipping clone and install."
fi

# --- 步骤 2: 动态创建 config.yaml 文件 ---
if [ -n "$CONFIG_YAML" ]; then
    echo "[Config] Found CONFIG_YAML secret. Creating config.yaml file..."
    echo "$CONFIG_YAML" > /home/node/app/config.yaml
else
    echo "[Config] CRITICAL: CONFIG_YAML secret not found."
    exit 1
fi

# --- 步骤 3: 配置并恢复云存档 (后台任务) ---
run_auto_save_in_background() {
    while true; do
        echo "[Auto-Save] Sleeping for ${AUTOSAVE_INTERVAL:-30} minutes..."
        sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
        echo "[Auto-Save] Waking up and saving data..."
        /opt/scripts/save.sh
        echo "[Auto-Save] Save process finished."
    done
}

if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "[Cloud Save] Config detected, initializing..."
    # 确保 data 目录存在
    mkdir -p /home/node/app/data
    cd /home/node/app/data
    /opt/scripts/config.sh "$REPO_URL" "$GITHUB_TOKEN"
    /opt/scripts/load.sh
    run_auto_save_in_background &
    echo "[Cloud Save] Auto-save process started in the background."
else
    echo "[Cloud Save] Warning: Secrets not found, skipping cloud save setup."
fi

# --- 步骤 4: 启动 SillyTavern 主程序 ---
echo "[Main] All setup complete. Starting SillyTavern..."
cd /home/node/app
exec tini -- node server.js
