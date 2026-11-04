#!/bin/bash
# 把 SurfCore 插件注册进 DSH 桌面版 profile（自动备份 + 幂等）
# 用法： bash scripts/setup-dsh-plugin.sh [--dir /path/to/surfcore] [--profile ~/.dsh/profiles/desktop]
set -euo pipefail
SURFCORE_DIR="${SURFCORE_DIR:-$HOME/Desktop/qq-bot/surfcore}"
PROFILE_DIR="${PROFILE_DIR:-$HOME/.dsh/profiles/desktop}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) SURFCORE_DIR="$2"; shift 2 ;;
    --profile) PROFILE_DIR="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done
say() { printf '\033[1;36m[dsh]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[ -f "$SURFCORE_DIR/package.json" ] || die "找不到 $SURFCORE_DIR/package.json（先运行 scripts/install.sh）"
[ -f "$PROFILE_DIR/package.json" ] || die "找不到 DSH profile：$PROFILE_DIR（DSH 桌面版未安装或路径不同，用 --profile 指定）"

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

TS="$(date +%Y%m%d-%H%M%S)"
BK="$HOME/.dsh/surfcore/backups/dsh-plugin-$TS"
mkdir -p "$BK"
cp -a "$PROFILE_DIR/package.json" "$BK/" 2>/dev/null || true
cp -a "$PROFILE_DIR/cordis.patch.yml" "$BK/" 2>/dev/null || true
say "已备份 profile → $BK"

SURFCORE_DIR="$SURFCORE_DIR" PROFILE_DIR="$PROFILE_DIR" "$NODE" - <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const surf = process.env.SURFCORE_DIR;
const prof = process.env.PROFILE_DIR;
const pkgPath = path.join(prof, 'package.json');
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

const deps = pkg.dependencies || (pkg.dependencies = {});
deps.surfcore = `link:${surf}`;
const profile = pkg.dsh
  && pkg.dsh.profile
  && Array.isArray(pkg.dsh.profile.bundles)
  ? pkg.dsh.profile.bundles
  : (() => { throw new Error('profile package.json 缺 dsh.profile.bundles'); })();
if (!profile.includes('surfcore')) profile.push('surfcore');
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');

// node_modules 链接
const nm = path.join(prof, 'node_modules');
fs.mkdirSync(nm, { recursive: true });
const link = path.join(nm, 'surfcore');
try { fs.rmSync(link, { recursive: true, force: true }); } catch {}
fs.symlinkSync(surf, link, 'dir');

// cordis.patch.yml：让桌面端允许本机回环（桥接 :3100 才能访问）
const patchPath = path.join(prof, 'cordis.patch.yml');
if (fs.existsSync(patchPath)) {
  const req = createRequire(path.join(surf, 'package.json'));
  const yaml = req('js-yaml');
  const raw = fs.readFileSync(patchPath, 'utf8');
  let doc = yaml.load(raw) || [];
  if (!Array.isArray(doc)) throw new Error('cordis.patch.yml 顶层不是数组');
  let entry = doc.find((e) => e && e.id === 'desktop-shell');
  if (!entry) {
    entry = { id: 'desktop-shell', config: {} };
    doc.push(entry);
  }
  entry.config = entry.config || {};
  entry.config.openBrowser = true;
  entry.config.networkExposure = 'loopback';
  fs.writeFileSync(patchPath, yaml.dump(doc, { lineWidth: 200, noRefs: true }));
  console.log('  ✅ cordis.patch.yml: openBrowser=true, networkExposure=loopback');
}
console.log('  ✅ package.json: bundles += surfcore, dependencies.surfcore = link:' + surf);
console.log('  ✅ node_modules/surfcore → ' + surf);
NODE

say "完成。重启 DSH 后：设置 → SurfCore"
