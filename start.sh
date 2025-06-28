#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 步骤 1: 【已简化】直接在运行时动态克隆和安装 ---
# 我们不再在 Dockerfile 中进行任何重量级操作，以确保镜像的“纯洁”
# 所有操作都在容器启动时完成
echo "[Stealth] Starting stealth deployment..."
if [ -z "$(ls -A /home/node/app)" ]; then
    git clone -b staging --depth 1 https://github.com/SillyTavern/SillyTavern.git .
    npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force
fi

# --- 步骤 2: 【最终决定性修复】检查由 Configmap 挂载的配置文件 ---
CONFIG_FILE_PATH="/home/node/app/config.yaml"
echo "[Config] Checking for configuration file provided by Configmap..."
if [ ! -f "$CONFIG_FILE_PATH" ]; then
    echo "[Config] CRITICAL: Config file not found. Please ensure the Configmap is set up correctly."
    exit 1
fi

# --- 步骤 3: 【已移除】不再需要云存档加载 ---
# 云存档将在 SillyTavern 自己的插件或功能中处理，或者暂时放弃以确保主程序能运行

# --- 步骤 4: 【最终奥义】以单前台进程模式启动 SillyTavern ---
echo "[Main] All setup complete. Starting SillyTavern as a foreground process..."
cd /home/node/app

# exec 是关键，它会用 node 进程替换当前的 shell 进程，成为容器的唯一主宰
# 我们将内存限制直接加在这里，并监听所有地址
# 平台会直接监控这个进程的健康状况
exec node --max-old-space-size=4096 server.js --host 0.0.0.0
