#!/bin/bash
# macOS DSH QQ Bot —— 主安装脚本
# 用法：
#   bash scripts/install.sh --dir "$HOME/Desktop/qq-bot"
#   OWNER_QQ=12345678 ALLOW_GROUP=123456789 bash scripts/install.sh --dir /path
# 参数：--dir <安装目录> --ref <surfcore commit> --dry-run
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/Desktop/qq-bot}"
SURFCORE_REPO="${SURFCORE_REPO:-https://github.com/Mieksido/surfcore.git}"
SURFCORE_REF="${SURFCORE_REF:-0deb826}"
DRY_RUN=0
HERE="$(cd "$(dirname "$0")/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --ref) SURFCORE_REF="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

say() { printf '\033[1;36m[install]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "本脚本只支持 macOS"
[ "$(uname -m)" = "arm64" ] || say "警告：仅在 Apple Silicon 上验证过（当前 $(uname -m)）"
command -v git >/dev/null || die "需要 git（xcode-select --install）"

# ---- Node 探测 ----
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
[ -n "$NODE" ] || die "找不到 Node.js ≥22.13：请安装 https://nodejs.org 或 Homebrew node，或用 SURFCORE_NODE=/path/to/node 指定"
NODE_VER="$("$NODE" -p 'process.versions.node')"
say "Node: $NODE (v$NODE_VER)"
"$NODE" -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=13)?0:1)' \
  || die "Node 版本过低（需要 ≥22.13）"

# ---- 拉取 SurfCore ----
say "安装目录: $INSTALL_DIR"
if [ "$DRY_RUN" = "1" ]; then
  say "dry-run：将 clone $SURFCORE_REPO @ $SURFCORE_REF 并应用 $HERE/patches/*.patch"
  exit 0
fi
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
if [ ! -d surfcore/.git ]; then
  say "clone SurfCore…"
  git clone "$SURFCORE_REPO" surfcore
else
  say "surfcore 已存在，跳过 clone"
fi
git -C surfcore fetch --all --quiet || true
git -C surfcore checkout "$SURFCORE_REF" --quiet 2>/dev/null || say "警告：切到 $SURFCORE_REF 失败，继续用当前分支"

# ---- 应用补丁 ----
say "应用 macOS 补丁…"
for p in "$HERE"/patches/*.patch; do
  name="$(basename "$p")"
  if git -C surfcore apply --check "$p" 2>/dev/null; then
    git -C surfcore apply "$p" && say "  ✅ $name"
  elif git -C surfcore apply --reverse --check "$p" 2>/dev/null; then
    say "  ↷ ${name}（已应用）"
  else
    say "  ⚠️ $name 应用失败（上游可能已变更），继续"
  fi
done

# ---- 依赖 ----
say "安装依赖…"
NPM="$(dirname "$NODE")/npm"
[ -x "$NPM" ] || NPM="$(command -v npm || true)"
[ -n "$NPM" ] || die "找不到 npm"
(cd surfcore && "$NPM" install --no-audit --no-fund) || die "npm install 失败"

# ---- 生成配置 ----
say "生成配置…"
gen_token() { "$NODE" -e 'console.log(require("crypto").randomBytes(16).toString("hex"))'; }
if [ ! -f surfcore/config.json ]; then
  OWNER_QQ="${OWNER_QQ:-}"
  if [ -z "$OWNER_QQ" ] && [ -t 0 ]; then
    read -r -p "你的 QQ 号（主人 / ownerQQ）: " OWNER_QQ
  fi
  [ -n "$OWNER_QQ" ] || die "缺少 OWNER_QQ（你的 QQ 号），可用环境变量传入"
  CONSOLE_TOKEN="${CONSOLE_TOKEN:-$(gen_token)}"
  ACCESS_TOKEN="${ACCESS_TOKEN:-surfcore-$(gen_token | cut -c1-16)}"
  ALLOW_PRIVATE="${ALLOW_PRIVATE:-$OWNER_QQ}"
  ALLOW_GROUP="${ALLOW_GROUP:-}"
  TMPCFG="$INSTALL_DIR/.config.gen.json"
  cp "$HERE/config/config.example.json" "$TMPCFG"
  SURFCORE_CFG="$TMPCFG" OWNER_QQ="$OWNER_QQ" CONSOLE_TOKEN="$CONSOLE_TOKEN" \
  ACCESS_TOKEN="$ACCESS_TOKEN" ALLOW_PRIVATE="$ALLOW_PRIVATE" ALLOW_GROUP="$ALLOW_GROUP" \
  "$NODE" - <<'NODE'
const fs = require('node:fs');
const p = process.env.SURFCORE_CFG;
const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
cfg.ownerQQ = Number(process.env.OWNER_QQ);
cfg.admin.qq = String(process.env.OWNER_QQ);
cfg.consoleToken = process.env.CONSOLE_TOKEN;
cfg.snowluma.accessToken = process.env.ACCESS_TOKEN;
cfg.allow.private = String(process.env.ALLOW_PRIVATE).split(',').map(s => Number(s.trim())).filter(Boolean);
cfg.allow.groups = String(process.env.ALLOW_GROUP || '').split(',').map(s => Number(s.trim())).filter(Boolean);
fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
NODE
  mv "$TMPCFG" surfcore/config.json
  say "  ✅ config.json（ownerQQ=${OWNER_QQ}，consoleToken 已生成）"
else
  say "  ↷ config.json 已存在，保留"
fi

# ---- 启动脚本 ----
say "生成启动脚本…"
cat > "$INSTALL_DIR/start.command" <<EOF
#!/bin/bash
cd "\$(dirname "\$0")"
NODE="$NODE" bash "$HERE/scripts/start-surfcore.sh" --dir "\$(pwd)/surfcore"
EOF
cat > "$INSTALL_DIR/stop.command" <<EOF
#!/bin/bash
TOKEN=\$(python3 -c "import json;print(json.load(open('$(echo "$INSTALL_DIR" | sed 's/[\/&]/\\&/g')/surfcore/config.json'))['consoleToken'])" 2>/dev/null || true)
curl -sS -X POST -H "x-console-token: \$TOKEN" http://127.0.0.1:3100/api/stop >/dev/null 2>&1 || true
echo "已请求停止桥接"
EOF
chmod +x "$INSTALL_DIR/start.command" "$INSTALL_DIR/stop.command"

# ---- 自动注册到 DSH（若存在 profile）----
PROFILE="$HOME/.dsh/profiles/desktop/package.json"
if [ -f "$PROFILE" ]; then
  say "检测到 DSH 桌面版 profile，注册 SurfCore 插件…"
  bash "$HERE/scripts/setup-dsh-plugin.sh" --dir "$INSTALL_DIR/surfcore" || say "⚠️ 自动注册失败，可稍后手动执行 scripts/setup-dsh-plugin.sh"
else
  say "未检测到 DSH 桌面版 profile（$PROFILE），跳过插件注册"
fi

cat <<EOF

✅ 安装完成

下一步（按顺序）：
  1) 安装 NapCat：   bash "$HERE/scripts/setup-napcat.sh"
  2) 启动机器人：     bash "$HERE/scripts/start-surfcore.sh" --dir "$INSTALL_DIR/surfcore"
  3) 你自己的 QQ（大号，有窗口）：
       bash "$HERE/scripts/setup-second-qq.sh"
  4) 把 surfcore 插件装进 DSH profile（见 docs/QUICKSTART.md「DSH 插件」一节）

详细说明：$HERE/docs/QUICKSTART.md
EOF
