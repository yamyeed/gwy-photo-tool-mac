#!/bin/bash
# 一键在 Mac（Apple Silicon）上运行国考官方「照片处理工具.exe」
# 原理：Whisky fork（Wine 11，非虚拟机）+ 微软官方 VC6 运行库补 MFC42
# 实测环境：macOS 26.3 / Apple Silicon / 2026-11-04
# 免责：本脚本不修改官方工具，不绕过任何校验；仅提供运行环境。
set -euo pipefail

WORK="$HOME/.gwy-photo-mac"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE="$SCRIPT_DIR/offline_bundle"   # 有 offline_bundle 时跳过 GitHub 下载（见 make_offline_bundle.sh）
SUPPORT="$HOME/Library/Application Support/com.franke.Whisky"
BOTTLES="$HOME/Library/Containers/com.franke.Whisky/Bottles"

# ---- 固定版本（2026-11-04 实测通过；如官方更新请自行核对哈希）----
DMG_URL="https://github.com/frankea/Whisky/releases/download/app-v3.7.0/Whisky-3.7.0.dmg"
DMG_SHA="8232b3b96be09b56e8f4e6b091c34a89c74b27c63ccfce92aa8ffe6ce3fbfee2"
LIB_URL="https://github.com/frankea/Whisky/releases/download/v3.1.1/Libraries.tar.gz"
LIB_SHA="01f3a1b43b98065fe20c529c1023b61dd79a6d2ad93bba6040865f646481ccf3"
ZIP_URL="http://cdn.cpta.com.cn/gwyzpclgj.zip"
ZIP_SHA="b9dc626c54d29b33a36b7ce2e7fea7a535d853bc2c2c0bbc9857e4f7b4dd25bb"
VC6_URL="https://download.microsoft.com/download/vc60pro/Update/2/W9XNT4/EN-US/VC6RedistSetup_deu.exe"
VC6_SHA="c2eb91d9c4448d50e46a32fecbcc3b418706d002beab9b5f4981de552098cee7"

# GitHub 加速镜像（直连慢时自动回退；失效可注释掉）
MIRRORS=("" "https://ghfast.top/" "https://gh-proxy.com/")

say()  { printf '\n\033[1m[%s]\033[0m %s\n' "$1" "$2"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

fetch() { # fetch <url> <out> <expected_sha256>
    local url="$1" out="$2" want="$3" u ok=0
    for pre in "${MIRRORS[@]}"; do
        u="${pre}${url}"
        echo "  下载: $u"
        if curl -sS -L --max-time 1800 --retry 2 -o "$out" "$u" 2>/dev/null; then
            if echo "$want  $out" | shasum -a 256 -c - >/dev/null 2>&1; then
                echo "  ✓ SHA-256 校验通过"; ok=1; break
            fi
            echo "  哈希不符，换源重试"; rm -f "$out"
        fi
    done
    [ "$ok" = 1 ] || die "下载/校验失败：$url"
}

say 0 "环境检查"
[ "$(uname -s)" = "Darwin" ] || die "仅支持 macOS"
[ "$(uname -m)" = "arm64" ]  || echo "  ⚠️ 非 Apple Silicon，未测试，可能失败"
command -v curl >/dev/null || die "需要 curl"
command -v python3 >/dev/null || die "需要 python3（系统自带）"
AVAIL=$(df -g "$HOME" | awk 'NR==2{print $4}')
[ "$AVAIL" -ge 2 ] || die "磁盘剩余不足 2 GB（当前 ${AVAIL} GB）"
mkdir -p "$WORK"

# ---- 1. Whisky App（含 WhiskyCmd / winetricks / cabextract）----
say 1 "安装 Whisky 兼容层（约 10 MB）"
if [ -x "$WORK/Whisky.app/Contents/Resources/WhiskyCmd" ]; then
    echo "  已存在，跳过"
elif [ -d "$OFFLINE/Whisky.app" ]; then
    echo "  使用离线包：$OFFLINE/Whisky.app"
    cp -R "$OFFLINE/Whisky.app" "$WORK/Whisky.app"
    xattr -cr "$WORK/Whisky.app"
else
    fetch "$DMG_URL" "$WORK/Whisky.dmg" "$DMG_SHA"
    MNT=$(mktemp -d)
    hdiutil attach "$WORK/Whisky.dmg" -nobrowse -readonly -mountpoint "$MNT" >/dev/null
    cp -R "$MNT/Whisky.app" "$WORK/Whisky.app"
    hdiutil detach "$MNT" >/dev/null; rm -rf "$MNT"
    xattr -cr "$WORK/Whisky.app"   # 去隔离属性
fi
WHISKYCMD="$WORK/Whisky.app/Contents/Resources/WhiskyCmd"
CABEXT="$WORK/Whisky.app/Contents/Resources/cabextract"
[ -x "$WHISKYCMD" ] || die "WhiskyCmd 不可用"

# ---- 2. Wine 11 运行时（约 332 MB）----
say 2 "安装 Wine 11 运行时（约 332 MB，视网速 1-15 分钟）"
if [ -x "$SUPPORT/Libraries/Wine/bin/wine" ]; then
    echo "  已存在，跳过"
elif [ -f "$OFFLINE/Libraries.tar.gz" ]; then
    echo "  使用离线包：$OFFLINE/Libraries.tar.gz"
    echo "$LIB_SHA  $OFFLINE/Libraries.tar.gz" | shasum -a 256 -c - >/dev/null 2>&1 \
        || die "离线包运行时哈希校验失败"
    mkdir -p "$SUPPORT"
    tar xzf "$OFFLINE/Libraries.tar.gz" -C "$SUPPORT"
else
    fetch "$LIB_URL" "$WORK/Libraries.tar.gz" "$LIB_SHA"
    mkdir -p "$SUPPORT"
    tar xzf "$WORK/Libraries.tar.gz" -C "$SUPPORT"
fi
WINE="$SUPPORT/Libraries/Wine/bin/wine"
[ -x "$WINE" ] || die "wine 未就绪：$WINE"
echo "  $($WINE --version 2>/dev/null | head -1)"

# ---- 3. 创建 bottle ----
say 3 "创建 Windows 容器（bottle）"
if find "$BOTTLES" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -q .; then
    echo "  已有 bottle，跳过"
else
    "$WHISKYCMD" create GwyPhoto >/dev/null 2>&1 || die "bottle 创建失败"
    echo "  ✓ $(find "$BOTTLES" -mindepth 1 -maxdepth 1 -type d | head -1)"
fi

# ---- 4. 下载并解包官方工具（不修改其任何文件）----
say 4 "下载官方照片处理工具（约 4.4 MB）"
if [ -f "$WORK/run_dir/PhotoProcess.exe" ]; then
    echo "  已存在，跳过"
else
    fetch "$ZIP_URL" "$WORK/gwyzpclgj.zip" "$ZIP_SHA"
    # zip 内文件名为 GBK 编码，用 python 解包并还原中文名；exe 改 ASCII 名避开兼容层路径坑
    python3 - "$WORK/gwyzpclgj.zip" "$WORK/run_dir" <<'PY'
import sys, zipfile, os
zpath, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
z = zipfile.ZipFile(zpath)
for i in z.infolist():
    try: name = i.filename.encode('cp437').decode('gbk')
    except Exception: name = i.filename
    data = z.read(i.filename)
    if name.lower().endswith('.exe'): name = 'PhotoProcess.exe'
    with open(os.path.join(out, name), 'wb') as f: f.write(data)
    print('  ', name)
PY
fi
EXE="$WORK/run_dir/PhotoProcess.exe"
[ -f "$EXE" ] || die "官方 exe 未就绪"

# ---- 5. 补 MFC42（微软官方 VC6 运行库，Wine 11 不自带）----
say 5 "补齐 MFC42 运行库（微软官方包，约 1.8 MB）"
if [ -f "$WORK/run_dir/mfc42.dll" ]; then
    echo "  已存在，跳过"
else
    fetch "$VC6_URL" "$WORK/VC6RedistSetup_deu.exe" "$VC6_SHA"
    mkdir -p "$WORK/vc6/dll"
    "$CABEXT" -q -F vcredist.exe -d "$WORK/vc6" "$WORK/VC6RedistSetup_deu.exe"
    "$CABEXT" -q -L -F '*.dll' -d "$WORK/vc6/dll" "$WORK/vc6/vcredist.exe"
    cp "$WORK/vc6/dll/mfc42.dll" "$WORK/run_dir/mfc42.dll"
fi

# ---- 6. 放入原图（可选）----
RUN="$WORK/run_dir"
if [ $# -ge 1 ] && [ -f "$1" ]; then
    cp "$1" "$RUN/source_photo.jpg"
    echo "已把原图放入运行目录：run_dir/source_photo.jpg（程序里直接选它）"
fi

# ---- 7. 启动 ----
say 6 "启动官方照片处理工具（Mac 原生窗口）"
# 取最近使用的 bottle（避免用户装有其他 Whisky 容器时选错）
BOTTLE=$(ls -dt "$BOTTLES"/*/ 2>/dev/null | head -1 | sed 's:/*$::')
export WINEPREFIX="$BOTTLE"
export WINEDLLOVERRIDES="d3d10core=n,b;d3d11=n,b;d3d12=;dxgi=n,b;winemetal=b"
export WINEDEBUG="fixme-all"
export WINE_MACH_PORT_TIMEOUT=30000 WINE_MACH_PORT_RETRY_COUNT=5
export WINEESYNC=1 WINEFSYNC=0 WINE_DISABLE_FAST_PATH=1
export TZ=Asia/Shanghai
echo "▶ 打开照片文件 → 审核通过 → 保存照片文件；产物默认为 报名照片.JPG（约 10K）"
echo "▶ 若按钮点不动：退出 Mac Mouse Fix 等鼠标增强工具，或用 Tab+空格 键盘操作"
cd "$RUN"
"$WINE" "$EXE"

# ---- 8. 找产物 ----
say 7 "查找产出"
SINCE=$(date -v-30M '+%Y%m%d%H%M%S')
FOUND=$(find "$RUN" "$HOME/Desktop" "$HOME/Documents" -maxdepth 2 \
    \( -name '报名照片*' -o -name '*.JPG' \) -newermt "$SINCE" 2>/dev/null | head -5)
if [ -n "$FOUND" ]; then echo "✅ 找到产出："; echo "$FOUND"
else echo "未自动找到 报名照片.*，请在保存位置确认"; fi
