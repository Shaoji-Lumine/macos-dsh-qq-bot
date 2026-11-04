#!/bin/bash
# 卸载：停桥接、停机器人 QQ、可选删除安装目录与「QQ大号」副本
set -euo pipefail
SURFCORE_DIR="${SURFCORE_DIR:-$HOME/Desktop/qq-bot/surfcore}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) SURFCORE_DIR="$2"; shift 2 ;;
    --remove-files) REMOVE=1; shift ;;
    --remove-second-qq) REMOVE_QQ=1; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done
TOKEN="$(/usr/bin/python3 -c "import json;print(json.load(open('$SURFCORE_DIR/config.json'))['consoleToken'])" 2>/dev/null || true)"
[ -n "$TOKEN" ] && curl -sS -X POST -H "x-console-token: $TOKEN" http://127.0.0.1:3100/api/stop >/dev/null 2>&1 || true
echo "已停止桥接"
if [ "${REMOVE:-0}" = "1" ]; then
  rm -rf "$(dirname "$SURFCORE_DIR")"
  echo "已删除安装目录"
fi
if [ "${REMOVE_QQ:-0}" = "1" ]; then
  rm -rf "/Applications/QQ大号.app"
  echo "已删除 /Applications/QQ大号.app"
fi
