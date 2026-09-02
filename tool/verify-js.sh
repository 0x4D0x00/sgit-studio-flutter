#!/usr/bin/env bash
# dart2js 语义验证 —— **每次改帧编解码/位运算后必跑**。
#
# ⚠️ `flutter test` 跑在 Dart VM，与目标平台 web(dart2js) 的数值语义**不等价**。
# 最痛的一条：`ByteData.getUint64/setUint64` 在 dart2js 上直接抛，
# 于是帧解码器在 web 上从来没跑通，而 VM 单测全绿、没有一条会红。
#
# 这个脚本用同一个编译器(dart2js)产出 JS 并在 node 里执行，把这类问题挡在部署前。
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"

out=$(mktemp -t vjs-XXXX.js)
trap 'rm -f "$out" "$out".deps "$out".map' EXIT

dart compile js -o "$out" tool/verify_js_semantics.dart >/dev/null
node "$out"
