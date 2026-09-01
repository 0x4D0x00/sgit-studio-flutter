#!/usr/bin/env bash
# 生成 Web 端要用的 WASM 产物（全部来自 sgcode，Dart 侧不实现任何协议/加密逻辑）。
#
#   sgit_ffi_web ← sgit-ffi-web : 桌面 .so 的 Web 对应物。
#     · sgit_request           业务请求(协议编排在 sgit-protocol,与 native 同一份实现)
#     · wasm_*_data{,_gcm}     加密原语(它依赖 sgit-crypto,符号一并带出)
#   只需这一个模块 —— 不必再单独打 sgit_crypto,否则同样的代码进包两遍(多 483KB)。
#
# 依赖(已在本机装好):
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-bindgen-cli --version <与 Cargo.lock 里 wasm-bindgen 同版本>
# ⚠️ CLI 版本必须与 crate 依赖版本一致,否则 glue 与 wasm 不匹配、运行时报错。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SGCODE="/program/sgcode/sgcode-rs"
OUT="$REPO/web/pkg"

export PATH="$HOME/.cargo/bin:$PATH"

LOCK_VER="$(grep -A2 '^name = "wasm-bindgen"' "$SGCODE/Cargo.lock" | grep '^version' | head -1 | sed 's/.*"\(.*\)".*/\1/')"
CLI_VER="$(wasm-bindgen --version | awk '{print $2}')"
if [ "$LOCK_VER" != "$CLI_VER" ]; then
  echo "!! wasm-bindgen 版本不一致: Cargo.lock=$LOCK_VER, CLI=$CLI_VER" >&2
  echo "   修:cargo install wasm-bindgen-cli --version $LOCK_VER" >&2
  exit 1
fi

mkdir -p "$OUT"

build_one() {
  local crate="$1" artifact="$2"
  echo ">> cargo build -p $crate --target wasm32-unknown-unknown --release ..."
  (cd "$SGCODE" && cargo build -p "$crate" --target wasm32-unknown-unknown --release)
  echo ">> wasm-bindgen $artifact → $OUT ..."
  wasm-bindgen --target web --out-dir "$OUT" --no-typescript \
    "$SGCODE/target/wasm32-unknown-unknown/release/$artifact.wasm"
}

build_one sgit-ffi-web sgit_ffi_web

echo ">> 导出符号:"
for js in "$OUT"/sgit_ffi_web.js; do
  echo "   $(basename "$js"): $(grep -oE '^export function [a-z_]+' "$js" | sed 's/export function //' | tr '\n' ' ')"
done
echo ">> 产物:"
ls -la "$OUT"
echo ">> 记得跑 ./deploy/push-web.sh 让现网带上新 wasm。"
