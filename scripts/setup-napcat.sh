#!/bin/bash
# 安装 NapCat（macOS 注入 QQ）
# 官方安装器：https://github.com/NapNeko/NapCat-Mac-Installer （MIT/自定义，按其仓库许可）
# 用法： bash scripts/setup-napcat.sh [--open]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
NAP_CACHE="${NAP_CACHE:-$HOME/Downloads}"
OPEN_IT="${OPEN_IT:-1}"

say() { printf '\033[1;36m[napcat]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "/Applications/QQ.app" ] || die "请先从腾讯官网安装 QQ 到 /Applications/QQ.app"
command -v curl >/dev/null || die "需要 curl"
command -v unzip >/dev/null || die "需要 unzip（系统自带）"

say "查询 NapCat-Mac-Installer 最新版本…"
API="https://api.github.com/repos/NapNeko/NapCat-Mac-Installer/releases/latest"
ASSET_URL="$(curl -fsSL "$API" | /usr/bin/python3 -c '
import sys, json
d = json.load(sys.stdin)
for a in d.get("assets") or []:
    if a["name"].endswith(".zip"):
        print(a["browser_download_url"]); break
' 2>/dev/null || true)"
TAG="$(curl -fsSL "$API" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null || true)"
[ -n "$ASSET_URL" ] || die "无法获取安装器地址，请手动打开 https://github.com/NapNeko/NapCat-Mac-Installer/releases"

ZIP="$NAP_CACHE/NapCatInstaller-${TAG:-latest}.zip"
if [ ! -f "$ZIP" ]; then
  say "下载 $ASSET_URL"
  curl -fL --retry 3 -o "$ZIP" "$ASSET_URL"
fi
say "解压到 /tmp/napcat-installer"
rm -rf /tmp/napcat-installer && mkdir -p /tmp/napcat-installer
unzip -q -o "$ZIP" -d /tmp/napcat-installer
APP="$(find /tmp/napcat-installer -maxdepth 2 -name '*.app' | head -1)"
[ -n "$APP" ] || die "解压后没找到安装器 .app"

cat <<EOF

============================================================
NapCat 安装器已就绪：$APP

请在安装器里按下面步骤操作：
  1. 选择 NapCat 版本（默认最新）与下载方式，点「安装」
  2. 提示备份并修改 QQ 入口时，选择「切换程序入口 NapCat」
  3. 若被系统拒绝：系统设置 → 隐私与安全性 → App 管理 → 允许安装器
  4. 安装完成后从安装器启动 QQ（它会自动带 --no-sandbox）
  5. 用**机器人小号**扫码登录

配置位置（任一存在即可，安装器版本不同路径不同）：
  ~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/NapCat/config/
  ~/Library/Containers/com.tencent.qq/Data/Documents/napcat/config/

本仓库提供了 OneBot 11 示例配置：
  $HERE/config/onebot11.example.json
把它复制成 onebot11_<小号QQ>.json 放进上面的 config 目录，
再把 token 改成你的值（与 surfcore config.json 的 snowluma.accessToken 一致）。

注意：机器人 QQ 必须带 --no-sandbox 启动（安装器启动时已处理；
手动启动用： open -a "/Applications/QQ.app" --args --no-sandbox ）
============================================================
EOF

if [ "$OPEN_IT" = "1" ]; then
  say "打开安装器…"
  open "$APP"
fi
