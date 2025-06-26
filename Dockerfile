# 使用官方 Node.js 镜像
FROM node:lts-alpine3.19

# 安装基础系统依赖
RUN apk add --no-cache gcompat tini git unzip wget curl

# 定义工作目录
ARG APP_HOME=/home/node/app
WORKDIR ${APP_HOME}

# --- 在构建阶段完成所有重量级工作 ---
# 步骤 1: 克隆 SillyTavern
RUN git clone -b staging --depth 1 https://github.com/SillyTavern/SillyTavern.git .

# 步骤 2: 安装 npm 依赖
RUN npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force

# 步骤 3: 【最终关键修复】在执行编译时，增加 Node.js 的内存上限
# 我们为编译过程分配 4GB 的堆内存，以确保它能在任何构建环境中完成
RUN \
  echo "Pre-compiling frontend libraries with increased memory..." && \
  if [ -f "./docker/build-lib.js" ]; then \
    node --max-old-space-size=4096 "./docker/build-lib.js"; \
  elif [ -f "./build-lib.js" ]; then \
    node --max-old-space-size=4096 "./build-lib.js"; \
  fi

# --- 安装我们自己的启动和云存档脚本 ---
COPY ./scripts /opt/scripts
COPY start.sh /usr/local/bin/start.sh

# --- 设置权限 ---
RUN chmod +x /opt/scripts/*.sh /usr/local/bin/start.sh
RUN git config --global --add safe.directory "${APP_HOME}"
RUN chown -R node:node /home/node/app /opt/scripts

# --- 暴露端口并切换用户 ---
# Koyeb 会自动检测并使用正确的端口，但我们最好还是声明一下
EXPOSE 8000
USER node

# --- 最终入口点 ---
ENTRYPOINT ["/usr/local/bin/start.sh"]
