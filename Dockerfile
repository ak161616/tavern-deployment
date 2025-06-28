# 使用官方 Node.js 镜像
FROM node:lts-alpine3.19

# 只安装最最最基础的系统依赖
RUN apk add --no-cache gcompat tini git

# 定义并创建工作目录
WORKDIR /home/node/app

# --- 复制启动脚本 ---
# 这是我们唯一需要从仓库复制的东西
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# --- 设置权限 ---
RUN chown -R node:node /home/node/app

# --- 暴露端口并切换用户 ---
EXPOSE 8000
USER node

# --- 最终入口点 ---
# 容器启动时，直接执行我们那个干净的启动脚本
ENTRYPOINT ["/usr/local/bin/start.sh"]
