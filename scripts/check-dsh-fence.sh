#!/bin/bash
# 检查 DSH desktop-shell 配置是否合法（模式感知）。
# 合法组合：
#   compatibility + openBrowser:true  → 启动正常 + 桥接可访问（QQ 机器人可用）
#   extended/其它 + openBrowser:false → 启动正常，但桥接 403（QQ 机器人不可用）
# 非法组合：
#   extended + openBrowser:true → 启动校验失败，DSH 进入恢复/安全模式（会“崩”）
#   compatibility + openBrowser:false → 启动正常但桥接 403（机器人不回消息）
# 用法： bash scripts/check-dsh-fence.sh [--fix] [--profile <dir>]
set -euo pipefail
PROFILE_DIR="${PROFILE_DIR:-$HOME/.dsh/profiles/desktop}"
FIX=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1; shift ;;
    --profile) PROFILE_DIR="$2"; shift 2 ;;
    *) echo "未知参数: ${1}"; exit 1 ;;
  esac
done
YML="$PROFILE_DIR/cordis.patch.yml"
[ -f "$YML" ] || { echo "找不到 ${YML}"; exit 1; }
MODE=$(awk '/^- id: desktop-shell/{f=1} f&&/^[^ -]/{exit} f&&/mode:/{print $2; exit}' "$YML" | head -1)
MODE=${MODE:-compatibility}
CUR=$(awk '/^- id: desktop-shell/{f=1} f&&/^[^ -]/{exit} f&&/openBrowser:/{print $2; exit}' "$YML" | head -1)
echo "profile: ${YML}"
echo "mode=${MODE}  openBrowser=${CUR:-（未设置）}"
case "$MODE:$CUR" in
  compatibility:true)  echo "✅ 合法：启动正常，桥接可用（QQ 机器人可工作）"; exit 0 ;;
  extended:true|*:true) echo "❌ 非法：非兼容模式 + openBrowser:true → DSH 启动会失败进入安全模式（这就是崩溃原因）"; BAD=1 ;;
  compatibility:false|compatibility:) echo "⚠️ 合法但桥接不可用：兼容模式 + openBrowser 非 true → QQ 机器人会 403 不回消息"; BAD=1 ;;
  *) echo "✅ 合法：启动正常（此模式下桥接不可用，QQ 机器人需要 compatibility 模式）"; exit 0 ;;
esac
if [ "${BAD:-0}" = "1" ]; then
  if [ "$FIX" = "1" ]; then
    bash "$(cd "$(dirname "$0")" && pwd)/dsh-fence-guard.sh"
    echo "✅ 已修复；如需 DSH 立即生效请重启 DSH"
  else
    echo "  加 --fix 自动修复（兼容模式→openBrowser true；扩展模式→openBrowser false）"
    exit 2
  fi
fi
