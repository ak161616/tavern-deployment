# 使用官方 Node.js 镜像
FROM node:lts-alpine3.19

# 安装基础系统依赖
RUN apk add --no-cache gcompat tini git unzip wget curl

# 定义工作目录
ARG APP_HOME=/home/node/app
WORKDIR ${APP_HOME}

# --- 安装我们自己的启动和云存档脚本 ---
COPY ./scripts /opt/scripts
COPY start.sh /usr/local/bin/start.sh

# --- 设置权限 ---
RUN chmod +x /opt/scripts/*.sh /usr/local/bin/start.sh
RUN chown -R node:node /home/node/app /opt/scripts

# --- 暴露端口并切换用户 ---
EXPOSE 8000
USER node

# --- 最终入口点 ---
ENTRYPOINT ["/usr/local/bin/start.sh"]
