#!/bin/bash
# 一键切换 DSH 外壳模式，并自动设置合法的 openBrowser：
#   compatibility → 启动正常 + 桥接可用（QQ 机器人能工作）【推荐】
#   extended      → 原生扩展外壳 + 启动正常；但桥接 403，QQ 机器人不可用
# 用法： bash scripts/set-desktop-mode.sh compatibility|extended
set -euo pipefail
MODE="${1:-}"
case "$MODE" in compatibility|extended) ;; *) echo "用法: $0 compatibility|extended"; exit 1 ;; esac
YML="${PROFILE_DIR:-$HOME/.dsh/profiles/desktop}/cordis.patch.yml"
[ -f "$YML" ] || { echo "找不到 ${YML}"; exit 1; }
OB="true"; [ "$MODE" = "extended" ] && OB="false"
cp "$YML" "$YML.bak-switch-$(date +%Y%m%d-%H%M%S)"
# 在 desktop-shell 块内替换 mode / openBrowser（只改这两行）
awk -v mode="$MODE" -v ob="$OB" '
  /^- id: desktop-shell/ { inshell=1 }
  inshell && /^[^ -]/ { inshell=0 }
  inshell && /^[[:space:]]+mode:/ { sub(/mode:.*/, "mode: " mode); print; next }
  inshell && /^[[:space:]]+openBrowser:/ { sub(/openBrowser:.*/, "openBrowser: " ob); print; next }
  { print }
' "$YML" > "$YML.tmp" && mv "$YML.tmp" "$YML"
echo "✅ 已切换：mode=${MODE}, openBrowser=${OB}"
echo "   → Cmd+Q 重启 DSH 生效"
if [ "$MODE" = "extended" ]; then
  echo "   ⚠️ 扩展模式下桥接会 403：QQ 机器人不会回消息。想恢复机器人请切回 compatibility。"
fi
