#!/bin/bash
# DSH 宿主围栏守卫（模式感知版，2026-11-06）
#
# DSH 2.0.18 的硬约束：desktop-shell 的 openBrowser=true 只在 mode=compatibility
# 下合法。两种非法组合都会出事：
#   extended + openBrowser:true  → 启动校验失败（browser access requires compatibility
#                                  mode）→ 插件不注册窗口 → Electron 进入恢复/安全模式
#   compatibility + openBrowser:false → 启动正常，但桥接访问 DSH 被 403 拒 → QQ 机器人不回消息
# 因此守卫只做「按当前 mode 修正 openBrowser」，绝不改 mode 本身：
#   compatibility（或未写 mode）→ 保证 openBrowser:true
#   其它 mode（extended 等）    → 保证 openBrowser 不是 true（写成 false）
# 由 LaunchAgent 在文件变化/每分钟调用；幂等、带备份、日志可查。
set -euo pipefail
PROFILE_DIR="${PROFILE_DIR:-$HOME/.dsh/profiles/desktop}"
YML="$PROFILE_DIR/cordis.patch.yml"
LOG="${FENCE_LOG:-$HOME/Library/Logs/dsh-fence-guard.log}"
say() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
[ -f "$YML" ] || { say "找不到 ${YML}，跳过"; exit 0; }
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

MODE=$(awk '/^- id: desktop-shell/{f=1} f&&/^[^ -]/{exit} f&&/mode:/{print $2; exit}' "$YML" | head -1)
MODE=${MODE:-compatibility}
CUR=$(awk '/^- id: desktop-shell/{f=1} f&&/^[^ -]/{exit} f&&/openBrowser:/{print $2; exit}' "$YML" | head -1)

backup_once() {
  cp "$YML" "$YML.guard-bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  ls -1t "$YML".guard-bak-* 2>/dev/null | tail -n +21 | xargs -I{} rm -f {} 2>/dev/null || true
}

if [ "$MODE" = "compatibility" ]; then
  if [ "$CUR" = "true" ]; then exit 0; fi
  backup_once
  if grep -qE "openBrowser:[[:space:]]*false" "$YML"; then
    sed -i '' -E 's/(openBrowser:[[:space:]]*)false/\1true/' "$YML"
  else
    perl -0pi -e 's/(- id: desktop-shell\n  name: dsh-plugin-desktop\n  config:\n)/$1    openBrowser: true\n/' "$YML" 2>/dev/null || printf '\n- id: desktop-shell\n  config:\n    openBrowser: true\n' >> "$YML"
  fi
  say "兼容模式：已设 openBrowser: true（桥接需要）"
  exit 0
fi

# 非兼容模式：openBrowser 不能是 true，否则 DSH 启动校验会失败进入安全模式
if [ "$CUR" = "true" ]; then
  backup_once
  sed -i '' -E 's/(openBrowser:[[:space:]]*)true/\1false/' "$YML"
  say "模式 ${MODE}：openBrowser:true 非法，已改为 false 以避免启动失败（此模式下 QQ 桥接会 403，需要时切回 compatibility）"
fi
exit 0
