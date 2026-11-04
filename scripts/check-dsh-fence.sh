#!/bin/bash
# 检查/修复 DSH 宿主围栏：桥接 :3100 与 DSH 通信依赖 desktop-shell.openBrowser=true。
# 症状：桥接日志 dshReady=false、事件流 0 帧、DSH 返回 403 forbidden、QQ 消息没人回。
# 用法： bash scripts/check-dsh-fence.sh [--fix] [--profile ~/.dsh/profiles/desktop]
set -euo pipefail
PROFILE_DIR="${PROFILE_DIR:-$HOME/.dsh/profiles/desktop}"
FIX=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1; shift ;;
    --profile) PROFILE_DIR="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done
YML="$PROFILE_DIR/cordis.patch.yml"
[ -f "$YML" ] || { echo "找不到 $YML"; exit 1; }
CUR=$(grep -nE "openBrowser:" "$YML" | head -1 || true)
echo "profile: $YML"
echo "当前: ${CUR:-（没有 openBrowser 配置）}"
if grep -qE "openBrowser:[[:space:]]*true" "$YML"; then
  echo "✅ openBrowser=true（桥接可以访问 DSH）"
  exit 0
fi
echo "⚠️ openBrowser 不是 true → 桥接会 403。"
if [ "$FIX" = "1" ]; then
  cp "$YML" "$YML.bak-$(date +%Y%m%d-%H%M%S)"
  if grep -qE "openBrowser:[[:space:]]*false" "$YML"; then
    sed -i '' -E 's/(openBrowser:[[:space:]]*)false/\1true/' "$YML"
  else
    printf '\n- id: desktop-shell\n  config:\n    openBrowser: true\n    networkExposure: loopback\n' >> "$YML"
  fi
  echo "✅ 已修复。请 Cmd+Q 重启 DSH 生效，然后重启桥接。"
else
  echo "加 --fix 自动修复（会先备份）"
  exit 2
fi
