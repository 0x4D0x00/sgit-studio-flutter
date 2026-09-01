#!/usr/bin/env bash
# 从 sgcode 构建并同步桌面端原生库到 native/（供 dart:ffi 加载、随桌面包分发）。
#
# 为什么不入 git：这些 .so/.dll 是 sgcode 的派生产物（22MB），入库既膨胀又必然与
# sgcode 源码脱节。与 Web 侧的 deploy/build-wasm.sh 同理 —— 产物按需重建，不进仓库。
#
#   ./deploy/sync-native.sh          # 构建 Linux 产物并同步
#
# Windows 的 .dll 需在 Windows 上（或交叉编译环境）构建后手工放进 native/windows/。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SGCODE="/program/sgcode/sgcode-rs"
OUT="$REPO/native/linux"

export PATH="$HOME/.cargo/bin:$PATH"

mkdir -p "$OUT"

# ⚠️ 现网 bin 是 dev profile（见部署手册），这里保持一致，别用 --release。
echo ">> cargo build -p sgit-ffi -p sgit-crypto ..."
(cd "$SGCODE" && cargo build -p sgit-ffi -p sgit-crypto)

for f in libsgit_ffi.so libsgit_crypto.so; do
  src="$SGCODE/target/debug/$f"
  [ -f "$src" ] || { echo "!! 缺产物: $src" >&2; exit 1; }
  cp -f "$src" "$OUT/$f"
  echo "   ok $f  $(du -h "$OUT/$f" | cut -f1)"
done

echo ">> 完成。产物在 $OUT（未入 git）。"
