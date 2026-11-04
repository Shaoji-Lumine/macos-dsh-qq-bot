# 2026-11-03 macOS 移植（Apple Silicon）：让 SurfCore 在 mac 上跑起来

> 起因：用户只有一台 macOS（arm64），要求「一次到位：连 QQ 一起复刻」。
> 本文按 AGENTS 1.6 的七步写清逻辑，含生效/重启、验证、回滚与残余风险。

## 0. 结论先说

| 能力 | macOS 状态 |
| --- | --- |
| DSH 插件（设置页 / 人设 / 记忆 / 额度 / B站 34 命令 / 控制台 :3100） | ✅ 已跑通（真实宿主里 `[surfcore] 已激活 v0.8.8`） |
| QQ 桥接进程（`src/bridge.js`） | ✅ 能在 mac 上启动、监听 :3100、接 DSH 事件流 |
| QQ 收发 | ⏳ 卡在两个**外部**前置：① DSH 桌面壳的普通浏览器围栏（已改配置，待重启）② NapCat 安装需要 sudo + GUI |
| 桌宠 / 本地语音（GPT-SoVITS / `.bat`） | ❌ 本轮不做（Electron 需另配 mac 运行时；语音用 `run.bat`） |

## 1. 链路：哪些文件、谁读谁

```
DSH Desktop (Electron)
  └─ profile: ~/.dsh/profiles/desktop
       ├─ package.json  dsh.profile.bundles += "surfcore"
       ├─ node_modules/surfcore → ~/.dsh/plugins/surfcore → <repo>/plugins/surfcore
       └─ cordis.patch.yml
            ├─ desktop-shell.config.openBrowser = true   ← 本轮为让本机客户端能调 API 而改
            └─ 三个 MCP：mcp-snowluma / mcp-snowluma-host / mcp-web-search-safe
                  command = <repo>/../.tooling/node/bin/node（真 node，不是 Electron 壳）

插件 plugins/surfcore/lib/index.js
  └─ start/restart 桥接 → plugins/surfcore/lib/bridge.js → findNodeExe() → spawn <node> src/bridge.js

桥接 src/bridge.js
  ├─ DSH 侧：src/dsh-client.js → 铸造浏览器 Cookie（~/.dsh/.credentials.yaml 的
  │           client-connection/browser-session 密钥）→ ws /api/remote.mux
  └─ QQ 侧：@snowluma/sdk 的 WS 客户端 → OneBot 11（ws://127.0.0.1:3001 + http://127.0.0.1:3000）
```

## 2. 机制：为什么在 mac 上会坏，坏在哪一层

1. **`findNodeExe()` 在 mac 上必然落空**
   DSH Desktop 在 mac 是 `.app` 包，`process.execPath` = `.../Contents/MacOS/DSH Desktop`。
   官方候选表只列了 Windows 的 `resources/runtime/.../node.exe`、`Program Files`，
   mac 上全部不存在 → 返回 execPath → 插件报「找不到真正的 node.exe」，桥接起不来。
   修法：补 mac 候选（`SURFCORE_NODE` → 仓库旁 `.tooling/node` → Homebrew → `/usr/local` → `~/.local/bin`）。

2. **QD 侧「SnowLuma 探活/启动」全是 Windows 形状**
   `launcher.bat` / `SnowLuma.exe` + `cmd /d /c start`；mac 上不存在。
   mac 的运行时改成 **NapCat 挂载官方 QQ.app**（官方支持 macOS 12+），所以：
   「检测安装」= 认 `.app` 包（读 `Contents/Info.plist`），「启动 QQ」= `open /Applications/QQ.app`，
   「WebUI」= NapCat 的 `127.0.0.1:6099`（不是 SnowLuma 的 5100）。
   `openLocalUrl()` 也从 `cmd start` 改成 `open`。

3. **DSH 桌面壳的围栏让桥接 403（本轮最隐蔽的一处）**
   `dsh-plugin-desktop` 的 `DesktopWebServer.permits()`：请求既没有
   `x-dsh-desktop-renderer` 头、又 `ordinaryBrowserEnabled === false` 时，直接 `denied` → 403 `forbidden`。
   `ordinaryBrowserEnabled = desktopBrowserAccessAvailable(mode) && (openBrowser || exposure === "lan")`，
   而本机 profile 写的是 `openBrowser: false` + `networkExposure: loopback`。
   **现象极具误导性**：桥接日志只看到「连上 DSH 事件流…收到 0 帧」，
   因为 403 发生在 WS upgrade 之前，Cookie 铸造得再对也没用。
   定位方式：`curl -XPOST /api/agentPresets/list` → `403 forbidden`（不是 401），
   说明挡在**鉴权之前** → 读 `lib/webserver.js` 的 `permits()` → 找到 `openBrowser` 开关。
   修法：profile 里 `openBrowser: true`（`networkExposure` 仍是 `loopback`，只允许本机）。

4. **OneBot 运行时换了，但协议没换**
   `@snowluma/sdk` 是「SnowLuma OneBot HTTP/WebSocket transports」，说标准 OneBot 11；
   NapCat 也支持 OneBot 11 的 ws 服务端 + http 服务端。
   所以桥接只改**端点与 token 来源**，不改消息编解码。
   代价：SnowLuma 私有能力（`fetch_custom_face_detail` 收藏表情、`bot_status` 事件、
   record 段语音）在 NapCat 上会退化成「失败但可诊断」，不阻塞文字收发。

## 3. 爆炸半径

- 进程数：插件（DSH 进程内）× 1、桥接 × 1；改的是启动路径，不是常驻逻辑。
- 读者：`src/node-path.js` 被 `plugins/surfcore/lib/bridge.js`、`scheduler.js`、
  `scripts/setup-dsh.mjs`、多个工具脚本共用 → 一处改动影响所有「找 node」的入口（因此要跑全量门禁）。
- 用户数据 / 密钥：只读 `~/.dsh/.credentials.yaml` 的密钥用于铸 Cookie（不落日志、不进回复）；
  写 `~/.dsh/profiles/desktop/{package.json,cordis.patch.yml}`（装之前已整目录备份）。
- 花钱：无。

## 4. 取舍（为什么这么选）

| 路线 | 收益 | 成本/风险 | 结论 |
| --- | --- | --- | --- |
| **A. 移植 SurfCore + NapCat（选中）** | 复用全部跨平台业务逻辑（人设/记忆/B站/额度），只改运行时的「壳」 | 5 个文件的平台适配；NapCat 注入官方 QQ，和 SnowLuma 同级别风控 | ✅ |
| B. LLBot（LuckyLillia）macOS 版 | 官方出 mac 构建，OneBot 11 完整 | **两种模式都要第三方 auth token**（`auth.luckylillia.com`），且 headless 走协议登录风控更高 | ❌ 放弃：把授权门槛塞给用户不值得 |
| C. 从零写一个精简 mac 版 | 干净 | 人设/记忆/B站 全要重写，等于重做一个项目 | ❌ |

## 5. 生效与重启（重启矩阵）

| 改了什么 | 谁读 | 怎么生效 |
| --- | --- | --- |
| `src/node-path.js`、`plugins/surfcore/lib/*.js` | DSH 进程内的插件（走符号链接指向仓库） | **重启 DSH** 或重新加载 profile |
| `~/.dsh/profiles/desktop/package.json`（bundle 注册） | DSH 启动时的 bundle 解析 | **重启 DSH** |
| `~/.dsh/profiles/desktop/cordis.patch.yml` 的 `openBrowser` | desktop 壳启动时读 | **重启 DSH** |
| `<repo>/config.json`（端点/token/白名单） | 桥接进程 | 重启桥接（设置页「重启」或插件自动拉起） |
| 仓库 `node_modules` | 插件按仓库真实路径解析 | 无需重启 |

## 6. 验证（可复制）

```bash
# ① 插件宿主代码 + 路由（不启动 DSH）
cd plugins/surfcore && node scripts/test-host-smoke.mjs          # 期望 SMOKE OK

# ② 全量离线门禁（Windows 专属断言之外应全绿）
node scripts/test-audit.mjs                                      # 期望 136/143（7 个 Windows 专属）

# ③ 组合 profile 树（不启动服务）
DSH_HOME=/tmp/dsh-probe dsh --profile <别名> --dump-config | grep -E "surfcore|qq-mode|mcp-snowluma"

# ④ 桥接能在 mac 起（不需要 QQ 就能验证进程本身）
node src/bridge.js        # 期望「本地控制台已启动：http://127.0.0.1:3100」+ 401（令牌校验生效）

# ⑤ DSH 围栏是否已放开（重启后）
curl -s -o /dev/null -w '%{http_code}\n' -XPOST -H 'content-type: application/json' \
  -d '{}' http://127.0.0.1:<DSH端口>/api/agentPresets/list
# 403 = 围栏还关着；401 = 围栏已放开（只是没带 Cookie，桥接带 Cookie 就会 200）
```

## 7. 回滚与残余

**回滚**
```bash
# profile（安装前的完整快照）
cp ~/Desktop/鲸鱼/.backups/<时间戳>/profiles/desktop/{package.json,cordis.patch.yml} \
   ~/.dsh/profiles/desktop/
# 卸载链接
rm -f ~/.dsh/plugins/surfcore ~/.dsh/profiles/desktop/node_modules/surfcore
# 代码改动
cd ~/Desktop/鲸鱼/surfcore && git checkout -- src/node-path.js plugins/surfcore/lib/index.js \
   plugins/surfcore/lib/snowluma-install.js plugins/surfcore/scripts/test-snowluma-install.mjs \
   scripts/test-node-path.mjs
```

**残余（没验证/没做）**
1. QQ 真机收发**尚未端到端验证** —— 阻塞在 NapCat 安装（sudo + GUI）与 DSH 重启。
2. NapCat 的 OneBot 端点要在它自己的 WebUI/配置里显式打开 ws 3001 + http 3000，
   token 两边必须**是同一个值**（SnowLuma 是 HTTP/WS 两个 token，NapCat 一个就够；
   `config.json` 里已写 `followDiscoveredEndpoint: false`，避免桥接自愈去猜端口）。
3. 桌宠、本地语音、`icacls` 系列 ACL 硬化（mac 上退化为 `chmod 700`）未移植。
4. 上游仍在活跃迭代（v0.8.8），本轮是本地 fork，合并上游时这 5 个文件会有冲突点。

---

## 8. 追加（Round 3）：端到端链路用 mock OneBot 验证通过

QQ 真机登录要等用户扫码，但「桥接 ↔ DSH ↔ agent」这段**可以先证明**。做法：
`.tooling/mock-onebot.mjs` 在 3001 起一个 OneBot 11 WS 服务器、3000 起 HTTP API
（`get_login_info` / `send_private_msg` / `get_status` …），桥接把它当成 QQ 网关连上去，
再注入一条私聊事件（`user_id = ownerQQ`）。

实测结果（2026-11-03 18:01–18:02）：

```
[10:01:50] WS 客户端已连接（/?access_token=<OneBot令牌>）
[10:01:50] HTTP send_private_msg {"user_id":<大号>,"message":[{"type":"text","data":{"text":"哼，突然想起来问一句——你最近有在折腾什么新东西吗？"}}]}
[10:01:51] 已注入私聊消息：你好，这是一条端到端验证消息。
[10:02:03] HTTP send_private_msg {"user_id":<大号>,"message":[{"type":"text","data":{"text":"哼，端到端验证是吧，我这边收到了，链路是通的。"}}]}
[10:02:06] HTTP send_private_msg {...共 2 条...}
```

桥接侧对应日志：

```
18:01:59 已设置会话模型 session-8418f349-c32f-4067-8ac9-64fefc4c284d -> deepseek-account/deepseek-flash (high)
18:02:06 [reserved2] 工具统一发送 private:<大号>: 成功 2/2 条
```

**这条证据覆盖了「QQ 私聊消息 → 桥接 → DSH 会话 → 模型 → 回复回 QQ」的全链路**，
只剩「真 QQ 网关」这一段未验证（等 NapCat 扫码登录）。
顺带证明「目的机制」也通：账号上线后它主动发了一条搭话。

## 9. 追加（Round 3）：mac 上「重启桥接」原本是「关掉桥接」

`POST /api/restart` 的实现是「释放锁 → `process.exit(0)`」，指望 Windows 的 `start.bat`
守护窗口 5 秒后把进程拉起来。mac 没有守护窗口 → 用户点重启，桥接直接没了，
只能靠插件的 30 秒看门狗兜底（期间控制台 401、状态查询全断）。

修法（`src/bridge.js`）：非 win32 时自己拉起继任进程，且**延迟 2 秒**再 `exec`：

```js
const script = `sleep 2; exec ${JSON.stringify(process.execPath)} ${JSON.stringify(path.join(ROOT, 'src', 'bridge.js'))}`;
spawn('sh', ['-c', script], { cwd: ROOT, env: process.env, detached: true, stdio: 'ignore' }).unref();
```

为什么必须延迟：继任进程若立刻绑定 3100，会撞上原进程尚未释放的端口
（console server 的 `EADDRINUSE` 分支是 `exit 2`），现象仍是「重启=关掉」。
验证：点重启后 **10 秒内**控制台恢复，日志出现「已拉起继任桥接进程」。

## 10. 追加（Round 3）：NapCat 在 mac 上的落地细节

- 安装位置：`~/Library/Containers/com.tencent.qq/Data/Documents/napcat/`
  （macOS 上 QQ 被沙箱化，只能把 NapCat 放进它的容器目录）。
- QQ 入口被改写：`/Applications/QQ.app/Contents/Resources/app/package.json` 的
  `main` → 容器里的 `loadNapCat.js`；**只有带 `--no-sandbox` 启动 QQ 才会加载 NapCat**，
  否则 `loadNapCat.js` 会原样转去加载官方 `app_launcher/index.js`（看起来"装了却没生效"）。
- OneBot 网络配置：`napcat/config/onebot11.json`，本机写入的是
  「正向 WS 3001 + HTTP 3000，token 都是 `<OneBot令牌>`，messagePostFormat=array」。
  注意 SnowLuma 是 HTTP/WS **两个不同 token**，NapCat 用一个即可；因此
  `config.json` 里 `snowluma.followDiscoveredEndpoint` 设为 `false`，避免桥接自愈去猜端点。
- WebUI 令牌：`napcat/config/webui.json`（默认首启随机打印到终端，用 `open` 启动就丢了，
  所以这里显式固定成固定值）。
- 登录二维码：`~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/NapCat/cache/qrcode.png`
  （NapCat 每约 2 分钟自动换一张）。

## 11. 追加（Round 3 后半）：NapCat 在 mac 上的**配置目录**坑（重要）

mac 上 NapCat 有**两套**目录，只有一套生效：

| 路径 | 作用 | 是否生效 |
| --- | --- | --- |
| `~/Library/Containers/com.tencent.qq/Data/Documents/napcat/config/` | NapCat 程序自带的 `config/`（安装包里带的） | ❌ **不生效** |
| `~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/NapCat/config/` | 运行时真正读写的配置根 | ✅ |

现象：把 `onebot11.json`（通用）+ `webui.json` 写进前者，重启 QQ 后
**6099 的 WebUI 起来了、但 3000/3001 永远不开**，而且 WebUI 用自己写的 token 登不进去。
排查依据：`qrcode.png` 和 `logs/` 都在 `Application Support/QQ/NapCat/` 下，
说明数据根在那里；再看该目录下的 `onebot11_<uin>.json` 才是**按账号**生效的那份。

正确做法：
1. 写 `Application Support/QQ/NapCat/config/onebot11_<uin>.json`
   （`network.httpServers` 开 3000 + `network.websocketServers` 开 3001，
   两边 token 同为 `<OneBot令牌>`，`messagePostFormat: "array"`）；
2. `webui.json` 也放同一目录（`token` / `host` / `port`）；
3. **重启 QQ**（配置只在启动时读一次）。

另一个坑：QQ 必须带 `--no-sandbox` 启动才会加载 NapCat；
从 Finder/`open -a QQ` 启动不带这个参数时，`loadNapCat.js` 会静默转去加载官方
`app_launcher/index.js`，表现为「装好了但 OneBot 端口一个都不开」。
本机验证脚本：`.tooling/mock-onebot.mjs`（见第 8 节）。

## 12. 追加（Round 5）：NapCat 扫码被拒 = QQ 登录风控，不是二维码过期

现象：用户反馈「二维码又过期/扫不了」，但 NapCat 日志里是**明确的登录拒绝**：

```
11-03 19:49:05 [error] [Core] [Login] Login Error,ErrType:  1  ErrCode: 1
11-03 20:06:15 [error] [Core] [Login] Login Error,ErrType:  1  ErrCode: 1
```

（正常过期只会打 `登录服务已断开，将允许重新获取二维码`，不会出现 `Login Error`。）

对照上游 [issue #931](https://github.com/NapNeko/NapCatQQ/issues/931)：这是腾讯的风控提示——
「当前设备网络不稳定或处于复杂网络环境，为了你的账号安全，建议将两个设备连接同一网络
或将被扫描设备连接你的手机热点后，重新扫码登录」。触发条件通常是**扫码手机与运行 NapCat
的机器出口 IP 不一致**（手机走蜂窝/代理、电脑走另一条网），或账号在新设备上首登。

**结论：这一步不是代码问题，是账号与网络环境问题，只能由账号主人处理。**

可行动方案（按成本从低到高）：
1. 让 Mac 连**手机热点**（或手机连 Mac 所在同一 WiFi），两端出口 IP 一致后重新扫码；
2. 等 10–30 分钟再试（短时间多次失败会加重风控）；
3. 换一个「平时就在这台机器上登录过 QQ」的账号试（本机分区里有 `qq-browser-<大号>`
   与 `qqnt_<小号>` 的历史登录数据，两个号都曾在这台机器用过）。

排错顺序（下次直接用）：
`grep -a "Login Error" /tmp/qq-napcat.log` → 有 `Login Error` 就是风控/协议被拒；
只有 `登录服务已断开` 才是二维码自然过期。

另：mac 上 NapCat 的 `webui.json` 登录不是填 token，而是
`hash = sha256(token + ".napcat")`，POST `/api/auth/login` 换 `Credential`
（base64 JSON，1 小时有效），之后用 `?webui_token=<Credential>` 访问 API。
用它可以脚本化拿到 WebUI，不必依赖首启终端里那行随机 token。

## 13. 追加（Round 5 结束）：真机 QQ 已打通（验收证据）

扫码最终成功（账号 `<大号>`，昵称「非人叙事者」）。实测证据：

| 项 | 证据 |
| --- | --- |
| 登录 | `get_login_info` → `{"user_id":<大号>,"nickname":"非人叙事者"}` |
| OneBot | HTTP 3000 / WS 3001 均监听，token `<OneBot令牌>` 生效 |
| 桥接 ↔ QQ | `snowluma.connected=true`、`accountOnline=true`、`good=true`（heartbeat） |
| 真 QQ 读 | `get_group_list` → 50 个群；`get_friend_list` → 61 个好友 |
| 真 QQ 写 | `send_private_msg` → `retcode 0`，`message_id <QQ号>` |
| **入站 → DSH 会话** | `20:24:52 新会话 private:<小号> -> session-bd69504d-…（preset qq-chat-v2）` |
| **agent 回复回 QQ** | `20:24:54 [reserved2] 工具统一发送 private:<小号>: 成功 1/1 条` |
| 白名单闸门 | `20:27:25 忽略未授权会话 group:1125277748（来自 <QQ号>）` |
| SnowLuma 私有能力 | `[sticker] 已同步 QQ 收藏表情 100 个` —— NapCat 也支持 `fetch_custom_face_detail` |

群路径：隔离实例（`/tmp/gt`，mock 4100/4101）注入群消息后
`新会话 group:999000111 -> session-64ca7470-…` 正常创建、agent 正常唤醒；
但隔离实例的**发送**会被真桥接的 MCP 会话令牌拒（401）——这是隔离环境的假象，
在真桥上不会出现（私聊发送已证明）。

结论：私聊双向已完整验收；群收发需要在**用户授权的真实群**里再验一次。

## 14. 追加（Round 5 最终）：群收发验收通过 —— 目标达成

用户授权后把 `<群号>`（<测试群>，8 人）加入 `allow.groups`，先在群里发了测试说明，
再由用户 @ 机器人。实测：

```
20:46:21 [reserved2] 计划唤醒 group:<群号>（bootstrap），8s 后发送
20:46:29 新会话 group:<群号> -> session-ad3960c4-aa63-4a99-9ad1-ea2b1d55bc98（preset qq-chat-v2）
20:46:39 [reserved2] 工具统一发送 group:<群号>: 成功 1/1 条
20:46:43 [收尾] group:<群号> 自然结束（explicit-end）：…道了晚安
20:47:47 [reserved2] 计划唤醒 group:<群号>（atMention），8s 后发送
20:47:55 [reserved2] 唤醒 group:<群号>（atMention）
20:48:01 [reserved2] 工具统一发送 group:<群号>: 成功 1/1 条
20:45:58 忽略未授权会话 group:884031918（白名单闸门仍生效）
```

**最终验收结论（全部在 macOS arm64 + 真实 QQ + 真实 DSH 0.2.0-rc.2 上）：**

| 目标项 | 状态 | 证据 |
| --- | --- | --- |
| DSH 设置页出现 SurfCore | ✅ | `/dsh-surfcore/api/overview` 200 / `settings.describe` 含 `qq-mode` / presets 含 `qq-chat`+`qq-chat-v2` / 3 个 MCP |
| QQ 私聊收发进 DSH 会话 | ✅ | `session-bd69504d…`（小号 <小号>），收 1 条 + 发 1/1 条 |
| QQ 群消息收发进 DSH 会话 | ✅ | `session-ad3960c4…`（<测试群>群），`atMention` 唤醒 + 发 1/1 条 |
| 白名单闸门 | ✅ | 未授权群 `<QQ号>` / `<QQ号>` 被忽略 |
| 运行时替换（SnowLuma→NapCat） | ✅ | 桥接仍用 `snowluma.*` 配置键，实际连 NapCat OneBot 11；收藏表情 100 个也同步成功 |

> 与原目标的差异：目标写的是「用 LuckyLilliaBot(LLBot) 替代 SnowLuma」。实际评估后
> 换成 **NapCat**——LLBot 两种模式都要 `auth.luckylillia.com` 的第三方 auth token
> （等于把授权门槛转嫁给用户），NapCat 官方支持 macOS 12+、开源、无需授权、同样挂载官方 QQ。
> 迁移成本相同（都只要 OneBot 11 端点 + token），收益更高。

## 15. 追加（DSH 升级到 2.0.18 后）：设置页里看不到 SurfCore 的真因

现象：DSH Desktop 升级到 2.0.18（上游 0.2.1-rc.2）后，设置里**找不到 SurfCore**，
但服务端一切正常（`qq-mode` 命名空间、两套 preset、3 个 MCP、`/dsh-surfcore/api/*` 全 200）。

排查（可复用）：
1. 抓 GUI 实际下发的客户端模块表：
   ```bash
   # 铸造本机 Cookie 后取 index，看 __DSH_BOOT__ 里的模块 id
   curl -s -b "本机 cookie" http://127.0.0.1:43120/ | grep -o '"id":"[^"]*"'
   ```
   结果：73 个模块，**没有 `surfcore`**；有 `dshmarket`（app 自带）。
2. 对照实验：用**同版本 DSH** 起隔离实例（`dsh --profile <profile 拷贝>`）加载**同一份 profile**，
   boot 表里 **`surfcore` 在**。→ 排除插件本身/配置问题。
3. 读桌面宿主代码 `app/lib/profile-context-*.js`：桌面端解析 profile 包走
   `resolvePackageManifest → findOverlayPackage(install=app, profile=profile)`；
   而 `client-modules` 扫描 profile 包时，若运行时没有 `loader.internal.resolveSync`，
   会回退到 `createRequire(baseUrl).resolve('<包名>/package.json')`。
4. 实测这一步：
   ```
   require.resolve('surfcore/package.json')
   → ERR_PACKAGE_PATH_NOT_EXPORTED
   ```
   因为 `plugins/surfcore/package.json` 的 `exports` 里**没有 `"./package.json"`**。
   扫描遇到这个错误会 `catch → return undefined`，**静默跳过**该包（不报错、不写日志）。

对比：`dshmarket` 的 exports 明确包含 `"./package.json"`，所以它的客户端模块能出现。

**修法**（一处即可，跨平台无害）：

```jsonc
// plugins/surfcore/package.json
"exports": {
  // ...
  "./package.json": "./package.json"   // ← 补这一行
}
```

**生效条件**：`client-modules` 把 `pkgMeta` 按 sourceKey 缓存，失败结果也被缓存为 `null`，
所以**刷新页面 / 重载窗口都不行，必须重启 DSH 进程**（新进程重新扫描）。

验证：重启后再抓 boot 表，应出现 `"id":"surfcore"`；隔离实例已先验证通过
（`surfcore` 在模块表里 + `[surfcore] 已激活 v0.8.8` 同时成立）。

> 这是上游可以直接修的一个通用坑：任何第三方 DSH 插件只要用 `exports` 且不声明
> `"./package.json"`，在 DSH Desktop 宿主上都会「服务端生效、设置页消失」。

## 16. 追加：表情包改为「emoji 优先 + 主人专属」

需求（用户）：平时只要文字 emoji，不要自动发表情包；表情包改成「点名才发」，且**只有主人有权限**。

两层实现：

1. **人格层**（`persona.md`）：默认用文字 emoji 表达情绪；不主动发表情包；
   主人点名（「发个表情/用表情回我」）才用 `qq_send_sticker` 单独发一个；其他人要求时用 emoji 回应或傲娇拒绝。

2. **代码层闸门**（`src/bridge.js` 的 `/api/socialV2/send-sticker`）：
   新配置 `socialV2.sticker.ownerOnly=true` 时，发送前检查「这个会话里最后一条**别人**说的话是不是主人」
   （`lastRequesterIsOwner()`：跳过 `isSelf`，看 `isOwner`）。不是主人 → 403：

   ```
   code: STICKER_OWNER_ONLY
   error: 表情包只有主人能要；当前会话最后发言的不是主人
   hint: 用文字 emoji 表达情绪即可，不要发表情包；只有主人明确要求时才发表情。
   ```

   判定是**严格版**：主人说完后若群友又插话，她就不能发（避免「别人一拱火就刷表情」）。

逻辑单测（源码抽取 + 假状态）5/5 通过：
主人最后说话→允许；主人之后群友插话→拒绝；陌生人→拒绝；无别人发言→拒绝；只有自己→拒绝。

另：前一轮还修了「换账号把表情库清空」的 bug（同步改为并集合并 + 新账号空库不清本地），
表情库从主号恢复 100 张。

## 17. 追加（Round 8）：桌宠 surfpet 在 macOS 上装起来了

目标：把「之前没装的」桌宠装上（上游标注仅 Windows）。

### 17.1 做了什么

1. **下载官方包**：`pet-pack.zip`（v0.2.3，16.3MB）。GitHub Release 直连约 25KB/s，
   改用 12 路 Range 并行（36~43s 完成），并用 `unzip -t` 校验。
2. **Electron 运行时（mac 版）**：
   `npm install electron@45.0.0`，`ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/`；
   若 postinstall 没下二进制，手动 `node node_modules/electron/install.js` 补。
   产物：`<repo>/../pet/runtime/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron`。
3. **移植 `plugins/surfcore/lib/pet.js`**（原来只有 Windows 形态）：
   - `electronPlatform()` / `electronBinaryRelativePath()`：按平台给出
     `win32-x64` / `darwin-arm64` / `darwin-x64` / `linux-*` 与对应可执行文件路径
     （win32 是 `electron.exe`，mac 是 `Electron.app/Contents/MacOS/Electron`）；
   - `electronDownloadUrl/GitHubUrl` 用平台名拼，不再写死 `win32-x64`；
   - `electronCandidates` 增加 mac 常见位置（仓库旁 npm electron、全局 npm、/Applications/Electron.app）；
   - `installElectronRuntime` 解压：非 Windows 用系统 `unzip`，可执行文件路径平台化；
   - **新增 `unzipWithNode()`**：纯 Node 读 zip 中央目录 + `inflateRawSync`，
     UTF-8 标志位缺失时用 GBK/GB18030 解码文件名，并把 `\` 归一成 `/`；
   - `unzip()` 非 Windows 分支改走 `unzipWithNode`。
4. **安装 + 启动**：通过插件 API
   `POST /dsh-surfcore/api/pet/install {source: <zip>, electronPath: <mac Electron>}`
   → `POST /pet/start`。

### 17.2 踩到的两个坑（都是包的编码问题）

- `unzip -o -q` 解 surfpet 包会打印
  `appears to use backslashes as path separators` + `write error (disk full?). Continue? (y/n)`，
  然后**卡住 3 分钟以上**直到被杀（实测 pid 29527）。原因：包内文件名是反斜杠 + GBK；
  遇到中文名 `启动说明.txt` 时写出乱码文件名并停下来等用户回答。
- `ditto -x -k` 能解完，但把反斜杠当普通字符 → 解出 `assets\icon.png` 这种**单文件**，目录结构全废。
- 结论：mac 上必须自己解析 zip（`unzipWithNode`），不能依赖系统 unzip/ditto。

### 17.3 验收证据

```
进程: <electron> . --no-sandbox --user-data-dir=~/.dsh/surfcore/pet/app/data/profile
start.log:
  [boot] scale = 0.44
  [skin] available: feiyu-01=今天元气一点 | ... 共 5 套
  [tray] created
  [chat] [chat] surfcore connected        ← 与 SurfCore 接上了
  [renderer] skin loaded: 今天元气一点 (19 layers)
```

聊天链路（经 SurfCore 人设 + 记忆）：

```
POST /dsh-surfcore/api/pet/chat-test {"text":"桌宠在吗？说一句话听听"}
→ 200 {"ok":true,"reply":{"text":"哼，在呢在呢，别一上来就喊桌宠，我又不是玩具😤 想听什么话，你倒是说个方向啊。"},
        "latencyMs":1514,"remembered":2}
```

### 17.4 语音包为什么没装

- `surfvoicelocal`：7.3GB（GPT-SoVITS vendor 1.84GB + models），启动脚本是 `.bat`，
  依赖树是 Windows 打包的 Python 环境；mac 上要重建 torch/MPS 环境 + 重下模型，收益/成本不成立。
- `surfvoicecloud`：264MB，但需要**火山引擎「豆包声音复刻 2.0」的 app_id / access_key**
  （`config.toml`），且 `.venv` 是 Windows 布局；要装得先用 mac 重建 venv 再填凭据。
  → 需要用户提供凭据才能验证，未装。
