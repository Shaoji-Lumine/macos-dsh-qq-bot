#!/bin/bash
# DSH 宿主围栏守卫：保证 profile 的 desktop-shell.openBrowser 永远是 true。
# 背景：在 DSH 里改设置/装插件会重写 profile，把 openBrowser 改回 false，
#       宿主围栏于是对桥接返回 403（dshReady=false、事件流 0 帧、QQ 不回消息）。
# 本脚本由 LaunchAgent 在文件变化/每分钟调用，幂等、带备份、日志可查。
set -euo pipefail
PROFILE_DIR="${PROFILE_DIR:-$HOME/.dsh/profiles/desktop}"
YML="$PROFILE_DIR/cordis.patch.yml"
LOG="${FENCE_LOG:-$HOME/Library/Logs/dsh-fence-guard.log}"
say() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
[ -f "$YML" ] || { say "找不到 ${YML}，跳过"; exit 0; }
if grep -qE "openBrowser:[[:space:]]*true" "$YML"; then exit 0; fi
mkdir -p "$(dirname "$LOG")"
cp "$YML" "$YML.guard-bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
if grep -qE "openBrowser:[[:space:]]*false" "$YML"; then
  sed -i '' -E 's/(openBrowser:[[:space:]]*)false/\1true/' "$YML"
  say "已把 openBrowser: false 改回 true（${YML}）"
else
  printf '\n- id: desktop-shell\n  config:\n    openBrowser: true\n    networkExposure: loopback\n' >> "$YML"
  say "openBrowser 配置缺失，已追加 true（${YML}）"
fi
# 备份只留最近 20 份，避免无限增长
ls -1t "$YML".guard-bak-* 2>/dev/null | tail -n +21 | xargs -I{} rm -f {} 2>/dev/null || true
