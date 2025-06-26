# 使用官方 Node.js 镜像
FROM node:lts-alpine3.19

# 安装基础系统依赖
RUN apk add --no-cache gcompat tini git unzip wget curl

# 定义工作目录
ARG APP_HOME=/home/node/app
WORKDIR ${APP_HOME}

# --- 【核心变更】在构建阶段完成所有重量级工作 ---
# 步骤 1: 克隆 SillyTavern
RUN git clone -b staging --depth 1 https://github.com/SillyTavern/SillyTavern.git .

# 步骤 2: 安装 npm 依赖
# 这一步会自动生成一个临时的默认config.yaml，后面会被我们的脚本覆盖
RUN npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force

# 步骤 3: 【关键】执行内存消耗巨大的编译任务
# 这个过程将在 Koyeb 强大的构建服务器上完成，而不是在您那个小小的免费实例里
RUN \
  echo "Pre-compiling frontend libraries during build time..." && \
  if [ -f "./docker/build-lib.js" ]; then \
    node "./docker/build-lib.js"; \
  elif [ -f "./build-lib.js" ]; then \
    node "./build-lib.js"; \
  fi

# --- 安装我们自己的启动和云存档脚本 ---
COPY ./scripts /opt/scripts
COPY start.sh /usr/local/bin/start.sh

# --- 设置权限 ---
RUN chmod +x /opt/scripts/*.sh /usr/local/bin/start.sh
RUN git config --global --add safe.directory "${APP_HOME}"
RUN chown -R node:node /home/node/app /opt/scripts

# --- 暴露端口并切换用户 ---
EXPOSE 8000
USER node

# --- 最终入口点 ---
ENTRYPOINT ["/usr/local/bin/start.sh"]
