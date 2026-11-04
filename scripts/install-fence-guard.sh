#!/bin/bash
# 安装 LaunchAgent：DSH profile 被改坏时自动恢复 openBrowser=true（永久防护）
# 用法： bash scripts/install-fence-guard.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PROFILE="${PROFILE_DIR:-$HOME/.dsh/profiles/desktop}"
SUPPORT_DIR="$HOME/Library/Application Support/surfcore"
SCRIPT_PATH="$SUPPORT_DIR/dsh-fence-guard.sh"
PLIST_SRC="$REPO/scripts/com.surfcore.dsh-fence.plist"
DEST="$HOME/Library/LaunchAgents/com.surfcore.dsh-fence.plist"
LOG="$HOME/Library/Logs/dsh-fence-guard.log"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$SUPPORT_DIR"
cp "$REPO/scripts/dsh-fence-guard.sh" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
sed -e "s#__SCRIPT__#$SCRIPT_PATH#" -e "s#__PROFILE__#$PROFILE/cordis.patch.yml#" -e "s#__LOG__#$LOG#" "$PLIST_SRC" > "$DEST"
launchctl bootout "gui/$(id -u)/com.surfcore.dsh-fence" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DEST"
launchctl kickstart -k "gui/$(id -u)/com.surfcore.dsh-fence" 2>/dev/null || true
echo "✅ 已安装守卫：$DEST"
echo "   监视：$PROFILE/cordis.patch.yml（变化/每分钟自动检查）"
echo "   日志：$LOG"
