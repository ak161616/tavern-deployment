#!/bin/sh
# 确保任何命令失败时立即退出
set -e

# --- 【最终决定性修复】以 root 身份，修复运行时权限 ---
# 无论 Claw Cloud 挂载了什么，我们都强制将应用目录的所有权交给 node 用户
# 这解决了所有 'Permission denied' 问题
echo "[Permissions] Taking ownership of all necessary directories as root..."
chown -R node:node /home/node/app
# 为了保险起见，也包括我们的脚本目录
if [ -d "/opt/scripts" ]; then
    chown -R node:node /opt/scripts
fi
echo "[Permissions] Ownership fixed."

# --- 【安全最佳实践】降级为非特权用户，执行所有后续操作 ---
# exec su-exec 会用 node 用户身份，执行后续的所有命令
# 这是最安全、最稳健的方式
echo "[Permissions] Dropping privileges to 'node' user..."
exec su-exec node -- sh -c '
    # 从这里开始，所有的命令都将以安全的 node 用户身份运行
    set -e

    # --- 步骤 1: 检查由 Configmap 挂载的配置文件 ---
    CONFIG_FILE_PATH="/home/node/app/config.yaml"
    if [ ! -f "$CONFIG_FILE_PATH" ]; then
        echo "[Config] CRITICAL: Config file not found. Please ensure the Configmap is set up correctly." >&2
        exit 1
    fi

    # --- 步骤 2: 配置并恢复云存档 ---
    if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
        mkdir -p /home/node/app/data
        cd /home/node/app/data
        # 这些脚本现在由 node 用户，在它自己拥有的目录里执行，畅通无阻
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
    
    # 我们保留这个内存参数，以防万一
    exec tini -- node --max-old-space-size=4096 server.js --host 0.0.0.0
'
