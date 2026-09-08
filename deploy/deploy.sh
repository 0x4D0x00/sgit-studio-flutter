#!/usr/bin/env bash
# SGiT Studio (Flutter Web) → docker 部署 / 热更新。
#
# 用法：
#   ./deploy/deploy.sh            # 构建 web + 首次建镜像&容器，或热替已存在容器
#   ./deploy/deploy.sh build      # 只 flutter build web
#   ./deploy/deploy.sh image      # 只重建镜像（需先 build）
#   ./deploy/deploy.sh cp         # 只 docker cp 热替 + reload（迭代期最快，需容器已在跑）
#
# ⚠️ ubuntu 已移出 docker 组（安全加固，见 memory sandbox-broker-privsep），
# 所有 docker 命令必须经 root。非 tty 场景用 expect 喂密码。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

IMAGE="sgit/studio-flutter-nginx:offline"
# ⚠️ 现网伺服本项目 web 产物(:18099)的容器叫 sgit-nexus（镜像 sgit/nexus-nginx:offline，
# nginx root 仍是 /usr/share/nginx/studio-flutter）。`cp` 子命令必须打到它，
# 否则 "No such container"。用 `CONTAINER=xxx ./deploy/deploy.sh cp` 覆盖。
CONTAINER="${CONTAINER:-sgit-nexus}"
DOCKERFILE="deploy/studio-flutter-nginx.Dockerfile"
WEBROOT_IN_CONTAINER="/usr/share/nginx/studio-flutter"

# Flutter SDK（宿主，装在 /opt/flutter 或 ~/flutter）。
if [ -x /opt/flutter/bin/flutter ]; then export PATH="$PATH:/opt/flutter/bin"; fi
if [ -x "$HOME/flutter/bin/flutter" ]; then export PATH="$PATH:$HOME/flutter/bin"; fi

# 国内镜像：避免 pub/flutter 资源卡 storage.googleapis.com（离线/受限网络）。
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"

DOCKER() { su root -c "docker $*"; }

build_web() {
  echo ">> flutter build web ..."
  flutter build web --base-href /
  patch_local_canvaskit
  echo ">> 产物：$REPO/build/web"
}

# Flutter Web 默认从 https://www.gstatic.com/flutter-canvaskit 拉 canvaskit 引擎、
# 从 fonts.gstatic.com 拉字体。内网/离线 + 我们的 CSP(connect-src 'self') 会挡死外链，
# 导致引擎起不来 → 白屏。产物里其实已打包本地 canvaskit/，给 loader 传
# config.canvasKitBaseUrl="canvaskit/" 即用本地。此 patch 幂等，每次 build 后跑。
patch_local_canvaskit() {
  local bs="build/web/flutter_bootstrap.js"
  if grep -q 'canvasKitBaseUrl:"canvaskit/"' "$bs"; then return 0; fi
  sed -i 's#_flutter.loader.load({#_flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"},#' "$bs"
  grep -q 'canvasKitBaseUrl:"canvaskit/"' "$bs" \
    && echo ">> patched: canvaskit 走本地(离线/CSP 安全)" \
    || { echo "!! patch canvaskit 失败" >&2; return 1; }
}

build_image() {
  echo ">> docker build $IMAGE ..."
  DOCKER "build -f $DOCKERFILE -t $IMAGE ."
}

run_container() {
  if DOCKER "ps -a --format '{{.Names}}'" | grep -qx "$CONTAINER"; then
    DOCKER "rm -f $CONTAINER"
  fi
  echo ">> docker run $CONTAINER (host 网络) ..."
  DOCKER "run -d --name $CONTAINER --network host --restart always $IMAGE"
}

hot_cp() {
  echo ">> docker cp build/web → $CONTAINER:$WEBROOT_IN_CONTAINER + reload ..."
  DOCKER "cp build/web/. $CONTAINER:$WEBROOT_IN_CONTAINER"
  DOCKER "exec $CONTAINER nginx -s reload"
}

case "${1:-all}" in
  build) build_web ;;
  image) build_image ;;
  cp)    hot_cp ;;
  all)
    build_web
    if DOCKER "ps --format '{{.Names}}'" | grep -qx "$CONTAINER"; then
      # 容器已在跑 → 迭代期热替（中间态，见 CLAUDE.md 铁律①）。
      hot_cp
    else
      build_image
      run_container
    fi
    ;;
  *) echo "未知参数: $1" >&2; exit 2 ;;
esac

echo ">> 完成。验证：curl -sS -o /dev/null -w '%{http_code}\\n' http://127.0.0.1:18099/"
