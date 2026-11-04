#!/bin/bash
# 复制一份 QQ.app，用于「大号」有窗口使用（机器人那份无窗口，互不干扰）
# 用法： bash scripts/setup-second-qq.sh [--name "QQ大号"] [--id com.tencent.qq2]
set -euo pipefail
NAME="QQ大号"
BUNDLE_ID="com.tencent.qq2"
SOURCE="/Applications/QQ.app"
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --id) BUNDLE_ID="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done
[ -d "$SOURCE" ] || { echo "找不到 $SOURCE"; exit 1; }
DEST="/Applications/$NAME.app"
if [ -d "$DEST" ]; then
  echo "已存在：$DEST（如需重建请先删除）"
  exit 0
fi
echo "复制 QQ.app → $DEST（约 640MB）…"
ditto "$SOURCE" "$DEST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$DEST/Contents/Info.plist"
# 注意：CFBundleName 必须保持 QQ，否则 Electron 找不到 "QQ Helper.app" 会崩溃
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $NAME" "$DEST/Contents/Info.plist"
echo "重新签名（ad-hoc）…"
codesign --force --deep --sign - "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
echo "启动 $NAME …"
open -a "$DEST"
cat <<EOF

✅ 已创建并启动「$NAME」（窗口正常）。

现在用它扫码登录你的**大号**；机器人那份（/Applications/QQ.app）保持无窗口后台运行。
EOF
