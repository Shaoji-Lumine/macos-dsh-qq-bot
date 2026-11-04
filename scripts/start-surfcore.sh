#!/bin/bash
# 启动机器人：QQ（无窗口）+ 桥接
# 用法： bash scripts/start-surfcore.sh --dir /path/to/surfcore [--no-qq]
set -euo pipefail
SURFCORE_DIR="${SURFCORE_DIR:-$HOME/Desktop/qq-bot/surfcore}"
START_QQ=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) SURFCORE_DIR="$2"; shift 2 ;;
    --no-qq) START_QQ=0; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done
say() { printf '\033[1;36m[surfcore]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$SURFCORE_DIR" ] || die "找不到 $SURFCORE_DIR（先跑 scripts/install.sh）"
find_node() {
  for c in "${SURFCORE_NODE:-}" "$(command -v node 2>/dev/null)" \
           "$HOME/.tooling/node/bin/node" \
           "$(command -v brew >/dev/null 2>&1 && brew --prefix)/bin/node" \
           /opt/homebrew/bin/node /usr/local/bin/node; do
    [ -n "${c:-}" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
NODE="$(find_node || true)"
[ -n "$NODE" ] || die "找不到 Node.js"

if [ "$START_QQ" = "1" ]; then
  if ! pgrep -f "/Applications/QQ.app/Contents/MacOS/QQ" >/dev/null 2>&1; then
    say "启动机器人 QQ（--no-sandbox，无窗口）…"
    open -a "/Applications/QQ.app" --args --no-sandbox || die "启动 QQ 失败"
  else
    say "机器人 QQ 已在运行"
  fi
  say "等待 OneBot HTTP :3000…"
  for _ in $(seq 1 60); do
    nc -z 127.0.0.1 3000 2>/dev/null && { say "  OneBot 就绪"; break; }
    sleep 2
  done
fi

if ! nc -z 127.0.0.1 3100 2>/dev/null; then
  say "启动桥接…"
  (cd "$SURFCORE_DIR" && nohup "$NODE" src/bridge.js >/dev/null 2>&1 &)
  sleep 3
fi
if nc -z 127.0.0.1 3100 2>/dev/null; then
  say "✅ SurfCore 已启动：http://127.0.0.1:3100"
  say "   查看状态：curl -H \"x-console-token: \$(cat $SURFCORE_DIR/config.json | grep consoleToken | cut -d'\"' -f4)\" http://127.0.0.1:3100/api/status"
else
  die "桥接没起来，检查 $SURFCORE_DIR/state/bridge.log"
fi
