#!/bin/bash
# 在"已经装好环境"的机器上，把 Whisky + Wine 运行时打成离线依赖包，
# 让其他 Mac 免 GitHub 下载、免网络等待，解压即用。
# 产物：offline_bundle/ 目录 + gwy-photo-mac-offline.tar（单文件，方便网盘/Release 分发）
#
# 版权边界（打包即代表你接受）：
#   ✅ Whisky（GPL-3.0）、Wine 运行时（LGPL-2.1）——开源，允许再分发（保留许可与来源声明）
#   ❌ 官方照片工具 zip、微软 VC6 运行库——不入包，安装时由 setup_and_run.sh 从官方源下载
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$HOME/.gwy-photo-mac"
SUPPORT="$HOME/Library/Application Support/com.franke.Whisky"
OUT="$HERE/offline_bundle"
LIB_SHA="01f3a1b43b98065fe20c529c1023b61dd79a6d2ad93bba6040865f646481ccf3"
DMG_URL="https://github.com/frankea/Whisky/releases/download/app-v3.7.0/Whisky-3.7.0.dmg"
LIB_URL="https://github.com/frankea/Whisky/releases/download/v3.1.1/Libraries.tar.gz"

say() { printf '\n\033[1m[%s]\033[0m %s\n' "$1" "$2"; }
die() { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

mkdir -p "$OUT"

# ---- 1. Whisky.app ----
say 1 "收集 Whisky.app"
if [ -d "$WORK/Whisky.app" ]; then
    rm -rf "$OUT/Whisky.app"; cp -R "$WORK/Whisky.app" "$OUT/Whisky.app"
elif [ -d "$HERE/../_wine_trial/Whisky.app" ]; then
    rm -rf "$OUT/Whisky.app"; cp -R "$HERE/../_wine_trial/Whisky.app" "$OUT/Whisky.app"
else
    echo "  本机无 Whisky.app，从 GitHub 下载（10 MB）..."
    for pre in "" "https://ghfast.top/"; do
        curl -sS -L --max-time 900 -o "$WORK/Whisky.dmg" "${pre}${DMG_URL}" 2>/dev/null && break
    done
    MNT=$(mktemp -d)
    hdiutil attach "$WORK/Whisky.dmg" -nobrowse -readonly -mountpoint "$MNT" >/dev/null
    cp -R "$MNT/Whisky.app" "$OUT/Whisky.app"
    hdiutil detach "$MNT" >/dev/null; rm -rf "$MNT"
fi
[ -x "$OUT/Whisky.app/Contents/Resources/WhiskyCmd" ] || die "Whisky.app 不完整"
xattr -cr "$OUT/Whisky.app"
echo "  ✓ $(du -sh "$OUT/Whisky.app" | cut -f1)"

# ---- 2. Wine 运行时 ----
say 2 "收集 Wine 11 运行时（约 317 MB）"
LIB_SRC=""
for c in "$WORK/Libraries.tar.gz" "$HERE/../_wine_trial/Libraries.tar.gz"; do
    [ -f "$c" ] && LIB_SRC="$c" && break
done
if [ -z "$LIB_SRC" ]; then
    echo "  本机无原始 tar 包，尝试从已安装目录重打包..."
    [ -d "$SUPPORT/Libraries" ] || die "找不到 Wine 运行时，无法打包"
    LIB_SRC="$OUT/Libraries.tar.gz"
    tar czf "$LIB_SRC" -C "$SUPPORT" Libraries
fi
echo "$LIB_SHA  $LIB_SRC" | shasum -a 256 -c - >/dev/null 2>&1 \
    || die "运行时哈希与固定校验值不符（$LIB_SRC）"
cp "$LIB_SRC" "$OUT/Libraries.tar.gz"
echo "  ✓ $(du -sh "$OUT/Libraries.tar.gz" | cut -f1)"

# ---- 3. 包内说明 ----
say 3 "写入包说明"
cat > "$OUT/BUNDLE_README.md" <<'MD'
# offline_bundle 离线依赖包

内容：
- `Whisky.app` — Whisky fork 3.7.0（含 WhiskyCmd / winetricks / cabextract），GPL-3.0
  来源：https://github.com/frankea/Whisky （app-v3.7.0）
- `Libraries.tar.gz` — WhiskyWine 运行时 v3.1.1（Wine 11.0，LGPL-2.1），SHA-256
  `01f3a1b43b98065fe20c529c1023b61dd79a6d2ad93bba6040865f646481ccf3`
  来源：https://github.com/frankea/Whisky/releases/tag/v3.1.1

用法：把本目录与 setup_and_run.sh 放在同一目录，直接运行
    ./setup_and_run.sh 你的证件照.jpg
脚本检测到 offline_bundle/ 即跳过 GitHub 下载；官方照片工具（4.4 MB）与
微软 VC6 运行库（1.8 MB）仍从官方源下载并做哈希校验——这两样有版权限制，不入包。
MD

# ---- 4. 合成单文件 ----
say 4 "合成单文件 tar（内容已压缩，不再 gzip）"
TAR="$HERE/gwy-photo-mac-offline.tar"
rm -f "$TAR"
tar cf "$TAR" -C "$HERE" offline_bundle
SHA=$(shasum -a 256 "$TAR" | awk '{print $1}')
echo "  ✓ $TAR ($(du -sh "$TAR" | cut -f1))"
echo "  SHA-256: $SHA"

say 5 "完成"
echo "分发方式二选一："
echo "  a) 整包单文件：gwy-photo-mac-offline.tar（对方解开后与脚本同目录）"
echo "  b) 直接给 offline_bundle/ 目录 + 仓库其余文件"
