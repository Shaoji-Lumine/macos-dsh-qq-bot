# QUICKSTART（macOS）

> 目标：在 Apple Silicon Mac 上跑起「DSH + SurfCore + QQ 机器人」。
> 全程自托管：需要你自己的 DSH、QQ、DeepSeek 账号。

## 0. 前置

| 项 | 要求 |
| --- | --- |
| 系统 | macOS 13+（验证环境 macOS 26.6 / QQ 7.0.2） |
| DSH | DeepSeek Harness Desktop 2.x，已能正常对话 |
| QQ | 腾讯官网安装到 `/Applications/QQ.app` |
| Node | ≥ 22.13（Homebrew `brew install node` 或官方安装包） |
| 账号 | 机器人用小号（建议），你自己用大号 |

## 1. 安装本仓库的补丁包

```bash
git clone <本仓库> macos-dsh-qq-bot
cd macos-dsh-qq-bot
bash scripts/install.sh --dir "$HOME/Desktop/qq-bot"
```

- 会 clone 上游 SurfCore（pin 在 `0deb826`）并应用 `patches/`
- 交互式问你的 QQ 号（ownerQQ），自动生成 `consoleToken`
- 生成 `start.command` / `stop.command`

## 2. 安装 NapCat（QQ 的 OneBot 后端）

```bash
bash scripts/setup-napcat.sh
```

按安装器提示：选择 NapCat 版本 → 安装 → 切换程序入口为 NapCat → 启动 QQ → 用**机器人小号**扫码。

> 若提示权限不足：系统设置 → 隐私与安全性 → **App 管理** → 允许安装器。

配置：把 `config/onebot11.example.json` 复制到 NapCat 配置目录，命名 `onebot11_<小号QQ>.json`，
把两处 `CHANGE_ME` 改成与 `surfcore/config.json` 中 `snowluma.accessToken` 相同的值。

NapCat 配置目录（两个路径视安装器版本而定）：

```
~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/NapCat/config/
~/Library/Containers/com.tencent.qq/Data/Documents/napcat/config/
```

## 3. 启动机器人（无窗口）

```bash
bash scripts/start-surfcore.sh --dir "$HOME/Desktop/qq-bot/surfcore"
```

它会：以 `--no-sandbox` 启动 QQ（机器人小号，**无窗口**）→ 等 OneBot `:3000` → 起桥接 `:3100`。

验证：

```bash
TOKEN=$(python3 -c "import json;print(json.load(open('$HOME/Desktop/qq-bot/surfcore/config.json'))['consoleToken'])")
curl -s -H "x-console-token: $TOKEN" http://127.0.0.1:3100/api/status | python3 -m json.tool | head -30
```

三个关键字段：`dshReady: true`、`snowluma.connected: true`、`mode: reserved2`。

## 4. 你自己的 QQ（大号，有窗口）

QQ 7.0.2 在 macOS 上带 `--no-sandbox` 会**创建不出窗口**，所以机器人那份必须无窗口。
你自己用大号聊天，需要一个独立副本：

```bash
bash scripts/setup-second-qq.sh
```

它会复制 `/Applications/QQ.app` → `/Applications/QQ大号.app`，改 bundle id 并 ad-hoc 签名。
之后用「QQ大号」扫码登录大号即可，与机器人互不影响。

## 5. 把插件装进 DSH

`install.sh` 检测到 `~/.dsh/profiles/desktop` 时会**自动注册**。手动执行（或重新注册）：

```bash
bash scripts/setup-dsh-plugin.sh --dir "$HOME/Desktop/qq-bot/surfcore"
```

它会（幂等，带备份）：
1. `package.json` → `bundles` 追加 `surfcore`，`dependencies.surfcore = link:<安装目录>`
2. `node_modules/surfcore` 软链到安装目录
3. `cordis.patch.yml` 里 `desktop-shell` 设 `openBrowser: true` / `networkExposure: loopback`（桥接 :3100 才能被访问）

然后**重启 DSH**，`设置 → SurfCore` 出现即成功。

> 若你的 DSH 用了非默认 profile 路径：`--profile <目录>`。

## 6. 验证

- 私聊机器人：能回复
- 群里 @ 机器人：能回复
- 发语音条：`state/bridge.log` 里出现 `[asr] 语音转文字成功`
- 发小黄脸：模型上下文里是 `[表情:微笑]` 而不是数字 id

## 7. 常见问题

见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。
