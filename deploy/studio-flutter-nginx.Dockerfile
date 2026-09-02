# SGiT Studio 前端（Flutter Web）：nginx 直伺服 build/web + 反代 gateway/auth。
#
# 照 sgit-studio 的模式（envsubst 端口参数化 + host 网络运行）。
#
# 构建上下文 = 仓库根（sgit-studio-flutter/）。构建前须先 `flutter build web` 产出 build/web。
#   ./build/web                 Flutter Web 构建产物
#   ./deploy/studio-flutter.conf.template nginx server 块模板（端口用 ${STUDIO_FLUTTER_HTTP_PORT}/${GATEWAY_PORT}/${AUTH_PORT}）
FROM nginx:1.27-bookworm

# Flutter Web 静态产物。
COPY build/web /usr/share/nginx/studio-flutter

# server 块模板 → entrypoint 启动时 envsubst 渲染成 /etc/nginx/conf.d/studio-flutter.conf。
COPY deploy/studio-flutter.conf.template /etc/nginx/templates/studio-flutter.conf.template
# 只替换这三个端口变量；其余 $ 开头的 nginx 变量原样保留。
ENV NGINX_ENVSUBST_FILTER='(STUDIO_FLUTTER_HTTP_PORT|GATEWAY_PORT|AUTH_PORT|SERVER_PORT)'
# 端口变量的容器内默认值（compose/运行时可覆盖）。
ENV STUDIO_FLUTTER_HTTP_PORT=18099 GATEWAY_PORT=38788 AUTH_PORT=38787 SERVER_PORT=32717
# 去掉 nginx 默认 server（listen 80 default_server 会与本 server 块冲突）。
RUN rm -f /etc/nginx/conf.d/default.conf

STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
