#!/usr/bin/env bash
# 从 sgcode 构建并同步桌面端原生库到 native/（供 dart:ffi 加载、随桌面包分发）。
#
# 为什么不入 git：这些 .so/.dll 是 sgcode 的派生产物（60MB+），入库既膨胀又必然与
# sgcode 源码脱节。与 Web 侧的 deploy/build-wasm.sh 同理 —— 产物按需重建，不进仓库。
# （`.gitignore` 里 `/native/` 已有此规则。两个 .dll 曾在该规则之前被误提交，
#  已用 `git rm --cached` 撤出追踪 —— 所以本脚本是**唯一**的产物来源。）
#
#   ./deploy/sync-native.sh                    # 按当前系统构建并同步
#   SGCODE_RS=/path/to/sgcode-rs ./deploy/...  # 指定 sgcode 位置
#
# 按运行平台自动选目标目录与产物名。Windows 上请在 Git Bash / MSYS 里跑。
# 交叉编译不在本脚本范围内 —— 各平台在各自机器上跑一次。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# sgcode 的 checkout 位置因机器而异。
#
# 顺序：显式 SGCODE_RS → 几个常见位置里**第一个真实存在**的。
# 原先只有一个写死的默认值，而它在多数机器上并不存在 —— 于是每次都要记着
# 传环境变量，忘了就报"找不到 sgcode-rs"，对第一次跑这个脚本的人尤其劝退。
if [ -n "${SGCODE_RS:-}" ]; then
  SGCODE="$SGCODE_RS"
else
  SGCODE=""
  for c in     "/program/sgcode/sgcode-rs"     "$HOME/sgcode-rs"     "$(dirname "$REPO")/sgit-code/sgcode-rs"     "$(dirname "$REPO")/sgcode-rs"; do
    [ -d "$c" ] && { SGCODE="$c"; break; }
  done
  # 一个都没找到时仍给出默认值，好让下面那句检查报出清楚的路径。
  SGCODE="${SGCODE:-/program/sgcode/sgcode-rs}"
  echo ">> 自动探测到 sgcode-rs: $SGCODE（用 SGCODE_RS= 可覆盖）"
fi

export PATH="$HOME/.cargo/bin:$PATH"

# 按平台定产物名与落地目录。名字必须与 Dart 侧 `DynamicLibrary.open()` 的实参一致
# （见 lib/data/transport/kernel/kernel_client_io.dart 的 _openLib）。
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    OUT="$REPO/native/windows"; FILES=(sgit_ffi.dll sgit_crypto.dll sgcode-helper.exe) ;;
  Darwin)
    OUT="$REPO/native/macos";   FILES=(libsgit_ffi.dylib libsgit_crypto.dylib sgcode-helper) ;;
  Linux)
    OUT="$REPO/native/linux";   FILES=(libsgit_ffi.so libsgit_crypto.so sgcode-helper) ;;
  *)
    echo "!! 不认识的平台: $(uname -s)" >&2; exit 1 ;;
esac

[ -d "$SGCODE" ] || { echo "!! 找不到 sgcode-rs: $SGCODE（用 SGCODE_RS= 指定）" >&2; exit 1; }
mkdir -p "$OUT"

# ⚠️ **必须 --release。** 这两个 crate 是**随包分发的库**，不是现网 bin ——
# 「现网 bin 用 dev profile」那条铁律对它们不适用（docs/KERNEL_FFI.md §7 明确写了这一点）。
# 内核帧的流式解析上 dev / release 差一个数量级，而那正是整个 FFI 方案的全部意义；
# 用 debug 产物分发等于把方案的收益扔掉，还会让契约 §8 的性能验收项无从谈起。
# ⚠️ **sgcode-helper 也要一起出**，而且必须是**同一次构建**。
#
# 本地引擎进沙箱读写文件、包 Windows 沙箱时要重新 exec 一个带 argv0/argv1
# 分发表的二进制（cdylib 没有自己的 main，见 sgit-ffi 的 resolve_sgcode_exe）。
# 它就是 `sgcode-arg0` 里的 `sgcode-helper` bin：只含分发表，约 8MB。以前这里
# 出的是整个 sgcode CLI（约 360MB，里面又是一份与 DLL 重复的引擎）。
#
# 实测代价：同事拿到只有 DLL 的包就缺这一环 —— 他机器上没有 sgcode.exe，
# 而我们这台恰好 `cargo install` 过，所以本机永远复现不出来。
#
# 「同一次构建」是要紧的：引擎内嵌在 DLL 里，fs-helper 走进程间 JSON 协议，
# 版本错位的毛病极难查。客户端查找时也把随包这份排在 PATH 之前，正是为此。
#
# ⚠️ 别给这条加 `--bin sgcode-helper`：cargo 的目标选择对**所有** `-p` 生效，
# 加了就只编那一个 bin，DLL 被静默跳过，拷走的是上一次的旧 DLL。
# `-p sgcode-arg0` 本身就会编出它唯一的 bin。
echo ">> cargo build --release -p sgit-ffi -p sgit-crypto -p sgcode-arg0 ..."
(cd "$SGCODE" && cargo build --release -p sgit-ffi -p sgit-crypto -p sgcode-arg0)

for f in "${FILES[@]}"; do
  src="$SGCODE/target/release/$f"
  [ -f "$src" ] || { echo "!! 缺产物: $src" >&2; exit 1; }
  cp -f "$src" "$OUT/$f"
  echo "   ok $f  $(du -h "$OUT/$f" | cut -f1)"
done

# 冒烟检查：内核符号在不在。
#
# 这一步不是多余的 —— 仓库里曾长期放着一台**只有认证符号、没有 sgit_kernel_* 的**
# sgit_ffi.dll，于是内核通道一上线就在 lookupFunction 上抛，而报错长得像"DLL 没找到"。
# 符号表是这类问题唯一的硬证据，顺手验掉。
# 用 grep -a 直接在二进制里数，不依赖 strings/nm —— Git Bash 默认没有它们，
# 而"检查被静默跳过"和没有检查是一回事。
ffi="$OUT/${FILES[0]}"
want=12
n=$(grep -aoE 'sgit_kernel_[a-z_]+' "$ffi" | sort -u | wc -l | tr -d '[:space:]')
if [ "${n:-0}" -lt "$want" ]; then
  echo "!! $ffi 只找到 ${n:-0} 个 sgit_kernel_* 符号（应有 $want）—— 产物可能过时" >&2
  exit 1
fi
echo "   符号检查通过：$n 个 sgit_kernel_*"

echo ">> 完成。产物在 $OUT（未入 git，按需用本脚本重建）。"
