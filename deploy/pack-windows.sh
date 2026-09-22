#!/usr/bin/env bash
# Windows 桌面端：release 构建 + 自检 + 打 zip。
#
# 用法：
#   ./deploy/pack-windows.sh              # 构建 + 自检 + 打包
#   ./deploy/pack-windows.sh check        # 只对现有产物做自检（不构建）
#   SKIP_NATIVE=1 ./deploy/pack-windows.sh  # 跳过原生库重建（native/ 已是最新时）
#
# 产物：dist/sgit-studio-<日期>-windows-x64.zip
#
# ## 为什么需要这个脚本
#
# 手工拷 `build\windows\x64\runner\...` 发出去踩过两次，两次都**只有本机好使**：
#
# 1. **发 Debug 目录**。它硬依赖 `MSVCP140D.dll` / `VCRUNTIME140D.dll` /
#    `ucrtbased.dll` —— 全是 debug 运行库，微软不允许随包分发，只有装了
#    Visual Studio 的机器才有。发给装过 VS 的同事能跑，换个人就"找不到
#    MSVCP140D.dll"。所以这里**强制 release**。
# 2. **漏了 sgcode.exe**。本地引擎跑 shell / apply-patch / 沙箱要靠重新 exec
#    它做 argv0 分发（cdylib 没有自己的 main）。开发机 `cargo install` 过所以
#    永远不复现，同事那台直接报「内核连接超时(gateway 未响应)」—— 而本地模式
#    压根不碰 gateway，那句话把排查方向整个带偏了。
#
# 两条都不是"注意一点就能避免"的：它们在**打包者自己的机器上一定是好的**。
# 所以做成自检，让机器去记。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

OUT_DIR="$REPO/build/windows/x64/runner/Release"
DIST="$REPO/dist"

# 必须出现在包里的文件。少任何一个都不该发出去。
#
# ⚠️ `sgcode.exe` 在这张表里是要紧的 —— 它是唯一"少了也能启动、只是功能
# 残缺"的那种缺失，所以最容易漏，也最难被发现（见文件头 §2）。
REQUIRED=(
  sgit_studio_flutter.exe
  flutter_windows.dll
  sgit_ffi.dll
  sgit_crypto.dll
  sgcode.exe
)

# 不该出现在包里的文件。见到就是打错了 profile。
FORBIDDEN_PATTERNS=(
  "MSVCP140D.dll"
  "VCRUNTIME140D.dll"
  "ucrtbased.dll"
  "*.pdb"
)

self_check() {
  local dir="$1"
  local bad=0

  [ -d "$dir" ] || { echo "!! 产物目录不存在: $dir" >&2; return 1; }

  echo ">> 自检 $dir"
  for f in "${REQUIRED[@]}"; do
    if [ -f "$dir/$f" ]; then
      echo "   ok  $f  $(du -h "$dir/$f" | cut -f1)"
    else
      echo "   !! 缺 $f" >&2
      bad=1
    fi
  done

  # data/ 里是 Flutter 的资源与 icudtl.dat，没有它应用起不来。
  if [ -d "$dir/data" ]; then
    echo "   ok  data/"
  else
    echo "   !! 缺 data/ 目录" >&2
    bad=1
  fi

  for pat in "${FORBIDDEN_PATTERNS[@]}"; do
    # shellcheck disable=SC2086
    local hits
    hits=$(find "$dir" -maxdepth 1 -name "$pat" 2>/dev/null | head -3)
    if [ -n "$hits" ]; then
      echo "   !! 不该出现: $pat（debug 运行库或调试符号 —— 是不是打成 Debug 了？）" >&2
      bad=1
    fi
  done

  # ⚠️ **验 exe 的导入表**，不只看文件在不在。
  #
  # 文件清单查不出"打成了 debug profile" —— debug 的 exe 一样叫
  # sgit_studio_flutter.exe。真正的判据是它 import 了哪个 CRT：
  # 带 `D` 后缀（MSVCP140D）的就是 debug 版，那种包只有装了 VS 的机器能跑。
  #
  # 用 grep -a 直接在二进制里找，不依赖 dumpbin/objdump —— Git Bash 默认没有
  # 它们，而"检查被静默跳过"和没有检查是一回事。
  if grep -aqE "VCRUNTIME140D\.dll|MSVCP140D\.dll|ucrtbased\.dll" \
       "$dir/sgit_studio_flutter.exe" 2>/dev/null; then
    echo "   !! exe 导入了 debug CRT —— 这是 Debug 构建，不能分发" >&2
    bad=1
  else
    echo "   ok  exe 导入的是 release CRT"
  fi

  # 内核符号：仓库里曾长期放着一个只有认证符号、没有 sgit_kernel_* 的 DLL，
  # 于是内核通道一上线就在 lookupFunction 上抛，而报错长得像"DLL 没找到"。
  local n
  n=$(grep -aoE 'sgit_kernel_[a-z_]+' "$dir/sgit_ffi.dll" 2>/dev/null | sort -u | wc -l | tr -d '[:space:]')
  if [ "${n:-0}" -lt 12 ]; then
    echo "   !! sgit_ffi.dll 只有 ${n:-0} 个 sgit_kernel_* 符号（应 ≥12）—— 产物过时" >&2
    bad=1
  else
    echo "   ok  sgit_ffi.dll 有 $n 个 sgit_kernel_* 符号"
  fi

  # sgcode.exe 与 DLL 的构建时间差。
  #
  # 引擎内嵌在 DLL 里，而命令执行要 exec 那个 exe —— 两者版本错位的毛病极难
  # 查（表现是某些工具行为诡异，而不是干脆报错）。差一天以上就该警惕：
  # 多半是 exe 从别处拷来的，不是同一次构建产出。
  if [ -f "$dir/sgcode.exe" ] && [ -f "$dir/sgit_ffi.dll" ]; then
    local t1 t2 diff_h
    t1=$(stat -c %Y "$dir/sgcode.exe")
    t2=$(stat -c %Y "$dir/sgit_ffi.dll")
    diff_h=$(( (t1 > t2 ? t1 - t2 : t2 - t1) / 3600 ))
    if [ "$diff_h" -gt 24 ]; then
      echo "   ?? sgcode.exe 与 sgit_ffi.dll 构建时间差 ${diff_h} 小时 —— 确认是同一次构建？" >&2
    else
      echo "   ok  sgcode.exe 与 DLL 构建时间接近（差 ${diff_h}h）"
    fi
  fi

  [ "$bad" -eq 0 ] || { echo "!! 自检未通过，**不要分发**" >&2; return 1; }
  echo ">> 自检通过"
}

if [ "${1:-}" = "check" ]; then
  self_check "$OUT_DIR"
  exit $?
fi

# 1) 原生库（sgit_ffi.dll / sgit_crypto.dll / sgcode.exe）
if [ "${SKIP_NATIVE:-0}" != "1" ]; then
  echo ">> 同步原生库 …（要 cargo build --release，十几分钟）"
  bash "$REPO/deploy/sync-native.sh"
else
  echo ">> 跳过原生库重建（SKIP_NATIVE=1）"
fi

# 2) Flutter release 构建
#
# ⚠️ **必须 --release**。见文件头 §1：Debug 产物依赖不可分发的 debug CRT。
echo ">> flutter build windows --release …"
flutter build windows --release

# 3) 自检
self_check "$OUT_DIR"

# 4) 打包
mkdir -p "$DIST"
ZIP="$DIST/sgit-studio-$(date +%Y%m%d)-windows-x64.zip"
rm -f "$ZIP"
echo ">> 打包 → $ZIP"
# 从 Release 的**父目录**打，让 zip 里有一层 Release/ 之外的干净目录名。
(cd "$(dirname "$OUT_DIR")" && \
  if command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -Command \
      "Compress-Archive -Path 'Release\\*' -DestinationPath '$(cygpath -w "$ZIP" 2>/dev/null || echo "$ZIP")' -Force"
  else
    zip -qr "$ZIP" Release
  fi)

echo ">> 完成：$ZIP  $(du -h "$ZIP" | cut -f1)"
echo "   直接把这个 zip 发出去即可；解压后双击 sgit_studio_flutter.exe。"
