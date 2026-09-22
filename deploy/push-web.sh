#!/usr/bin/env bash
# 构建 web 产物并热替进 sgit-studio-flutter 的 nginx 容器。
#
# 为什么要有这个脚本:直接手敲 `python3 rootrun.py ...` 已经踩坑两次 ——
# rootrun.py 在 /program/sgit-align 下,在别处跑会 "No such file";若再把输出
# 重定向到 /dev/null,就变成**静默失败**,验的还是旧包,白白排查半天。
# 这里固定绝对路径、并且**绝不吞掉输出**,失败立刻 set -e 退出。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIGN_DIR=/program/sgit-align
# 现网伺服本项目 web 产物(:18099)的容器叫 sgit-studio-flutter
# （镜像 sgit/studio-flutter-nginx:offline，nginx root=/usr/share/nginx/studio-flutter）。
# 2026-09-11 从旧名 sgit-nexus 改过来，与项目名一致。
# 换容器时用 `CONTAINER=xxx ./deploy/push-web.sh` 覆盖，别再改死。
CONTAINER="${CONTAINER:-sgit-studio-flutter}"
WEBROOT=/usr/share/nginx/studio-flutter

: "${SU_PASS:?请先 export SU_PASS=<root 口令>}"

echo ">> [1/3] flutter build web ..."
"$REPO/deploy/deploy.sh" build

echo ">> [2/3] docker cp → $CONTAINER:$WEBROOT ..."
(cd "$ALIGN_DIR" && SU_PASS="$SU_PASS" python3 rootrun.py \
  "docker cp $REPO/build/web/. $CONTAINER:$WEBROOT && docker exec $CONTAINER nginx -s reload && echo RELOAD_OK")

echo ">> [3/3] 校验现网与本地产物一致 ..."
# ⚠️ 必须逐个校验:只看 main.dart.js 会漏掉「只改了 wasm」的情况(Dart 没变则 md5 不变,
# 看着"一致"其实 wasm 是旧的)。
check() {
  local rel="$1"
  local local_md5 remote_md5
  local_md5=$(md5sum "$REPO/build/web/$rel" | cut -d' ' -f1)
  remote_md5=$(curl -s "http://127.0.0.1:18099/$rel" | md5sum | cut -d' ' -f1)
  if [ "$local_md5" != "$remote_md5" ]; then
    echo "!! 现网与本地不一致: $rel local=$local_md5 remote=$remote_md5" >&2
    return 1
  fi
  echo "   ok  $rel  md5=$local_md5"
}
check main.dart.js
check pkg/sgit_ffi_web_bg.wasm
check pkg/sgit_ffi_web.js
check index.html
echo ">> 完成。本地==现网。"
