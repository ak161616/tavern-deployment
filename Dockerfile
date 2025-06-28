# 使用官方 Node.js 镜像
FROM node:lts-alpine3.19

# 【新】安装 su-exec (包含在 gosu 包中)，这是我们用来降级权限的工具
RUN apk add --no-cache gcompat tini git unzip wget curl gosu

# 定义工作目录
WORKDIR /home/node/app

# --- 在构建阶段完成所有重量级工作 ---
RUN git clone -b staging --depth 1 https://github.com/SillyTavern/SillyTavern.git .
RUN npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force
RUN node --max-old-space-size=4096 "./build-lib.js"

# --- 安装我们自己的启动和云存档脚本 ---
COPY ./scripts /opt/scripts
COPY start.sh /usr/local/bin/start.sh

# --- 设置脚本执行权限 ---
RUN chmod +x /opt/scripts/*.sh /usr/local/bin/start.sh
RUN git config --global --add safe.directory "${APP_HOME}"

# --- 【已移除】我们不再需要在这里进行 chown 或切换用户 ---
# RUN chown -R node:node ... (移除)
# USER node (移除)

# --- 暴露端口 ---
EXPOSE 8000

# --- 最终入口点 ---
# 容器将以 root 身份，启动我们的智能启动脚本
ENTRYPOINT ["/usr/local/bin/start.sh"]
