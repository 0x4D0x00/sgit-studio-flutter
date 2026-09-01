#!/usr/bin/env bash
# 把外置品牌目录的资源同步一份进 assets/brand/(随包兜底)。
#
# 为什么需要随包这一份:
#   · 现网/内网机上有 /opt/sgit/bin/brand,程序优先读它,换图换名即时生效;
#   · 但**客户机上的桌面端可能根本没有这个目录**(单机安装、Windows 机器),
#     此时就靠随包这份兜底,否则登录页没 logo、标题为空。
# 两者是「外置优先、随包兜底」的关系,不是二选一。
#
# 外置目录变了(换了客户品牌)就跑一次本脚本再出包,免得随包兜底还是旧品牌。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${SGIT_BRAND_DIR:-/opt/sgit/bin/brand}"
DST="$REPO/assets/brand"

[ -d "$SRC" ] || { echo "!! 外置品牌目录不存在: $SRC" >&2; exit 1; }

echo ">> 源: $SRC"
echo ">> 目标: $DST"

mkdir -p "$DST/images/login"

# 1) 文本配置(产品名/版权)。
cp -f "$SRC/brand.json" "$DST/brand.json"

# 2) 登录页图片。⚠️ 图片实体在 public/ 子目录下,brand.json 在根 —— 别搞混。
for f in login-bg.png logo-mark.png logo-wordmark.png; do
  cp -f "$SRC/public/images/login/$f" "$DST/images/login/$f"
done

echo ">> 已同步:"
find "$DST" -type f -printf '   %-46p %8s B\n' | sort
echo ">> 注意:assets 变了要重新 flutter build(桌面 & web)才会进包。"
