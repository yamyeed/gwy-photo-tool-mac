#!/bin/bash
# 全量卸载 setup_and_run.sh 安装的一切（约 1.2 GB）
# 覆盖：~/.gwy-photo-mac、~/Library/Application Support/com.franke.Whisky、bottle 容器
set -euo pipefail

TARGETS=(
    "$HOME/.gwy-photo-mac"
    "$HOME/Library/Application Support/com.franke.Whisky"
    "$HOME/Library/Containers/com.franke.Whisky"
)

echo "将删除以下目录："
du -sh "${TARGETS[@]}" 2>/dev/null || true
echo ""
printf '确认删除？输入 yes 继续: '
read -r ANS
[ "$ANS" = "yes" ] || { echo "已取消"; exit 0; }

# 先结束残留进程
pkill -f '.gwy-photo-mac/run_dir/PhotoProcess.exe' 2>/dev/null || true
pkill -f 'com.franke.Whisky/Libraries/Wine' 2>/dev/null || true
sleep 1

for t in "${TARGETS[@]}"; do
    if [ -e "$t" ]; then rm -rf "$t" && echo "✓ 已删除 $t"; else echo "- 不存在 $t"; fi
done
echo "卸载完成。"
