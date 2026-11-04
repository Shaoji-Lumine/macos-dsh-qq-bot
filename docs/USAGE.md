# 完整使用教程（macOS）

> 从零开始，到日常使用与运维。文中 `<你的QQ>`、`<小号QQ>`、`<群号>`、`<你的角色名>` 均为占位符。

---

## 0. 这套系统是什么

```
你（QQ 客户端）
   │  QQ 消息（私聊 / 群聊）
   ▼
NapCat  ← 注入在 QQ.app 里，把 QQ 变成 OneBot 11 服务（HTTP :3000 / WS :3001）
   │
   ▼
bridge 桥接进程（:3100）  ← 收发调度、上下文、记忆注入、发送限流
   │
   ▼
DSH Desktop（DeepSeek Harness）
   └─ SurfCore 插件：人设、记忆卡、QQ 工具、设置页（14 个标签）
```

| 组件 | 作用 | 由谁提供 |
| --- | --- | --- |
| DSH Desktop | 宿主，负责模型调用与会话 | 官方安装包 |
| SurfCore 插件 | 人格、记忆、QQ 桥接、设置页 | 本仓库补丁 + 上游 |
| 桥接 bridge.js | 联通 QQ 与 DSH 的进程（:3100） | 同上 |
| NapCat | QQ 的 OneBot 后端 | 官方 Release |
| QQ.app | 腾讯客户端 | 腾讯官网 |

---

## 1. 安装

### 1.1 准备清单

- macOS 13+（Apple Silicon 验证过）
- DSH Desktop 2.x，已能正常对话
- Node.js ≥ 22.13（`brew install node` 或官网包）
- QQ 从腾讯官网安装到 `/Applications/QQ.app`
- 一个**机器人 QQ 号**（建议小号）+ 一个你自己用的号（大号）

### 1.2 安装补丁与脚本

```bash
git clone <本仓库URL> macos-dsh-qq-bot
cd macos-dsh-qq-bot
OWNER_QQ=<你的QQ> bash scripts/install.sh --dir "$HOME/Desktop/qq-bot"
```

它会依次：

1. clone 上游 SurfCore（固定在 `0deb826` / v0.8.8）
2. 应用 `patches/` 里的 4 个 macOS 补丁
3. 安装依赖（npm）
4. 生成 `config.json`（ownerQQ、随机 consoleToken）
5. 生成 `start.command` / `stop.command`
6. 检测到 DSH 桌面版时，**自动注册插件**（写 profile + 开 openBrowser + 建软链，带备份）

> 可选环境变量：`ALLOW_GROUP=<群号>` 只回一个群；`CONSOLE_TOKEN=...` 指定控制台令牌；`SURFCORE_NODE=/path/to/node` 指定 Node。

### 1.3 安装 NapCat 与登录 QQ

```bash
bash scripts/setup-napcat.sh
```

按安装器提示操作：

1. 选择 NapCat 版本与下载方式，点「安装」
2. 提示备份并修改 QQ 入口时，选择「切换程序入口 NapCat」
3. 若系统拒绝：系统设置 → 隐私与安全性 → **App 管理** → 允许安装器
4. 从安装器启动 QQ，用**机器人小号**扫码登录

> **关键点**：机器人的 QQ 必须带 `--no-sandbox` 启动（安装器会自动处理）。不带这个参数，QQ 走官方入口，NapCat 不加载，表现为 3000/3001 端口不开。

### 1.4 OneBot 配置

把仓库里的 `config/onebot11.example.json` 复制到 NapCat 配置目录，命名 `onebot11_<小号QQ>.json`：

```bash
# 二选一（取决于安装器版本）
~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/NapCat/config/
~/Library/Containers/com.tencent.qq/Data/Documents/napcat/config/
```

把里面的两处 `CHANGE_ME` 改成和 `config.json` 中 `snowluma.accessToken` 相同的值。改完**重启 QQ**。

### 1.5 启动机器人

```bash
bash scripts/start-surfcore.sh --dir "$HOME/Desktop/qq-bot/surfcore"
```

会：无窗口启动 QQ → 等 OneBot `:3000` → 启动桥接 `:3100`。

### 1.6 验证

```bash
TOKEN=$(python3 -c "import json;print(json.load(open('$HOME/Desktop/qq-bot/surfcore/config.json'))['consoleToken'])")
curl -s -H "x-console-token: $TOKEN" http://127.0.0.1:3100/api/status | python3 -m json.tool | head -40
```

| 字段 | 期望 | 含义 |
| --- | --- | --- |
| `dshReady` | `true` | 桥接连上了 DSH |
| `snowluma.connected` | `true` | 连上了 QQ 的 OneBot |
| `snowluma.accountOnline` | `true` | QQ 账号在线 |
| `mode` | `reserved2` | 二代仿真模式（工具全开） |
| `role` | 你的角色名 | 当前人设 |

### 1.7 重启 DSH

完全退出 DSH（Cmd+Q）再打开。**设置 → SurfCore** 出现即成功。

---

## 2. 设置页：14 个标签怎么用

| 标签 | 主要用途 | 常用操作 |
| --- | --- | --- |
| **概览** | 全局状态、平台启动开关、看门狗 | 启动/停止 QQ 桥接；看桥接是否在线 |
| **角色** | 人格卡、称呼、角色切换 | 改人设、导入/导出角色、首次相遇 |
| **目的** | 主动搭话/目的机制 | 开关主动发言、看驱动强度 |
| **QQ** | QQ 相关全部配置 | 白名单、owner、发送频率、鱼群守则、黑话、表情、语音转写、Token 防爆破 |
| **语音** | TTS 语音包 | 选本地/云端、启动语音包、试听 |
| **桌宠** | surfpet 桌宠 | 填 Electron 路径、安装 pet-pack、启动 |
| **B站** | B站子系统 | 扫码登录、动态轮询、分享到群 |
| **Token 额度** | 每日花费/token 上限 | 设人民币或 token 阈值、看今日用量 |
| **观看历史** | B站观看记忆 | 同步/清理 |
| **记忆** | 记忆卡管理 | 查看记录、重置、容量告警阈值、全量卡 |
| **对齐** | QQ 与 B站记忆互通 | 双向注入开关、字数上限 |
| **扩展** | 工具能力开关 | 按需开启/关闭工具 |
| **全部参数** | JSON 级配置 | 高级调参（改前先备份） |
| **诊断** | 体检与日志 | 一键体检、看最近错误、自检 |

> 大部分设置改完需要重启桥接（设置页通常会给按钮）；`config.json` 是最终落盘位置。

---

## 3. config.json 关键字段

```jsonc
{
  "dsh": { "baseUrl": "http://127.0.0.1:3080", "model": "deepseek-flash", "followDefaultModel": true },
  "snowluma": {
    "wsUrl": "ws://127.0.0.1:3001",     // OneBot WS（NapCat 的 3001）
    "httpUrl": "http://127.0.0.1:3000",// OneBot HTTP（NapCat 的 3000）
    "accessToken": "与 OneBot 配置一致",
    "launcherPath": "/Applications/QQ.app",
    "napcatWebuiPort": 6099
  },
  "ownerQQ": 12345678,                  // 主人 QQ：私聊必回、可要表情包、防爆破豁免
  "consolePort": 3100,                  // 桥接控制台
  "consoleToken": "控制台令牌（脚本生成，勿外传）",
  "allow": { "private": [12345678], "groups": [] },  // 白名单；空 = 不回
  "deny":  { "users": [], "private": [], "groups": [] },

  "role": {
    "maxInjectChars": 6000,             // 核心卡注入上限（字符）
    "layerMaxChars": {                  // 分层独立预算：各层互不挤占；0 = 关闭该层
      "identity": 600, "tone": 1200, "scene": 800, "daily": 600
    }
  },

  "socialV2": {
    "vision":     { "imageInput": "true" },   // 允许把表情/图片发给模型（支持视觉时）
    "sticker":    { "enabled": true, "ownerOnly": true }, // 表情包只有主人能要
    "voice":      { "inboundAsr": true, "enabled": false }, // 入站语音转文字
    "send":       { "maxSendPerMinute": 8 },
    "prompt": {
      // 【积极性】/【反AI味】覆盖：空串 = 默认文案；false = 不注入；字符串 = 自定义
      "antiAi": "", "proactive": ""
    },
    "tokenGuard": {
      "enabled": true,
      "ownerUnlimited": true,        // 和主人聊不限流（额度仍生效）
      "maxWakesPerDay": 30,          // 每个群每日唤醒上限
      "privateMaxWakesPerDay": 20,   // 私聊每日唤醒上限
      "minWakeGapMs": 60000,         // 最小唤醒间隔
      "maxOutboundPerTurn": 10,      // 每次醒来最多发几条
      "maxDailyCostCNY": 10          // 每日花费上限（0 = 不限）
    }
  }
}
```

修改优先级：**设置页 > 直接改 config.json**（直接改完要重启桥接）。

---

## 4. QQ 功能使用

### 4.0 她能不能「看视频」

能，但分两层：

- **B站 子系统**（插件侧）：`debrief`/`watch-video` 可以读简介/字幕/弹幕/热评并抽帧拼九宫格看画面。
- **QQ 对话侧**（她本人）：补丁 0007 给她加了一个**只读**工具 `qq_look_bilibili_video`：
  你在 QQ 里发 B站 链接，她可以调用它读字幕 + 看九宫格画面，再跟你聊。

前置：
1. 装 ffmpeg（放到 `~/.dsh/surfcore/bili/bin/ffmpeg` 或 PATH）
2. B站 扫码登录（设置 → SurfCore → B站），生成 `~/.dsh/surfcore/bili/credentials.json`
3. 重启 DSH（MCP 工具在启动时加载）

没有登录时，工具会返回「还没有登录 B站…」而不是报错。

### 4.1 文字聊天

- 私聊：直接发消息
- 群聊：`@角色名` 或直接说（取决于鱼群守则）
- 引用回复：引用它的话再问，它按「回复对象」理解

### 4.2 表情与小黄脸

- **emoji**（如 😭😤）：纯文本，直接算在文字里
- **QQ 小黄脸**：入站会被转成可读名（如 `[表情:微笑]`），模型能理解
- **表情包**：只有 `ownerQQ` 能要（`sticker.ownerOnly: true`），其他人要会被拒绝
- 模型能看图时（`vision.imageInput: "true"`），表情包会以图片形式给模型

### 4.3 语音

- **发语音**：需要先装语音包（设置 → 语音 → 本地 8765 / 云端 8767），并在扩展里打开发语音工具
- **收语音**：QQ 侧转写可用时，桥接会调 `fetch_ptt_text`，把文字并进消息（日志 `[asr] 语音转文字成功`）
- 没有转写时保留 `[语音]` 占位，不影响其他消息

### 4.4 记忆机制

| 概念 | 说明 |
| --- | --- |
| 记忆卡（衰减） | 近期/重要/初次相遇记得清楚，其余随时间模糊 |
| 全量卡 | append-only 存档，不会被遗忘 |
| 清晰度 | `vivid/clear/fuzzy`，模糊后模型会说「记不清了」 |
| 容量告警 | 80/90/100% 三档，可设私聊提醒 |
| 首次相遇 | 置顶锚点，不会被衰减掉 |
| 重置 | 设置 → 记忆 → 重置（衰减卡/全量卡/巡检等不同范围） |

### 4.5 主动搭话与目的机制

- 「目的」标签控制主动发言：drive 强度、触发条件、频率
- 群越冷/越久没说话越容易触发；可临时关闭（专注模式）

### 4.6 Token 防爆破与额度

| 配置 | 作用 |
| --- | --- |
| `maxWakesPerDay` / `privateMaxWakesPerDay` | 每个会话每天最多被叫醒几次 |
| `minWakeGapMs` | 两次唤醒最小间隔 |
| `maxOutboundPerTurn` | 一次醒来最多发几条 |
| `directBypassGap/Day` | 被 @/叫到/引用/拍一拍时不受间隔和日限 |
| `ownerUnlimited` | 和主人聊天豁免以上限制（额度仍生效） |
| Token 额度（设置页） | 每日花费/token 上限，到 80/100% 会提醒/停 |

### 4.7 群聊行为

- **鱼群守则**：按群活跃度/发言比例决定是否插话，防刷屏
- **黑话学习**：从群里学梗（可关），学到的会进提示词
- **收尾判断**：话题结束时会自然收尾，不硬接

### 4.8 多个群/多个人

- 白名单：`allow.private`（QQ 号列表）、`allow.groups`（群号列表）
- 不在白名单的会话一律不响应
- 每个会话独立上下文与唤醒计数

---

## 5. 桌宠（可选）

### 5.1 装 Electron 运行时

```bash
cd ~/Desktop
mkdir -p pet/runtime && cd pet/runtime
npm init -y
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm install electron@45.0.0 --no-audit
```

### 5.2 装 pet-pack

设置 → 桌宠 → 安装包地址填官方 `pet-pack.zip` 的下载链接（或本地路径）→ 安装 → 启动。

Electron 路径填：

```
~/Desktop/pet/runtime/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron
```

### 5.3 联动

- 桌宠会读 `~/.dsh/surfcore/pet/host.json` 自动连上 SurfCore
- 右键：文本对话 / 语音对话 / 专注模式 / 换皮肤
- 它说的话会同步到 QQ 载体的记忆

---

## 6. 双开 QQ（大小号同时在线）

### 6.1 为什么需要

机器人那份 QQ 必须 `--no-sandbox`，而 mac 上带这个参数**不创建窗口**；你自己聊天需要窗口。

### 6.2 生成副本

```bash
bash scripts/setup-second-qq.sh
```

生成 `/Applications/QQ大号.app`（改 bundle id + ad-hoc 签名），窗口正常，可登录大号。

### 6.3 日常使用

| 用途 | 怎么启动 |
| --- | --- |
| 机器人（小号，无窗口） | `bash scripts/start-surfcore.sh` |
| 你自己（大号，有窗口） | `bash scripts/setup-second-qq.sh` 生成的 App，或 `open -a "/Applications/QQ大号.app"` |

### 6.4 注意

- QQ 更新后副本可能失效：删掉 `/Applications/QQ大号.app` 重新跑一次脚本
- 两份 QQ 数据独立，登录态互不影响

---

## 7. 日常运维

### 7.1 启停

```bash
bash scripts/start-surfcore.sh --dir "$HOME/Desktop/qq-bot/surfcore"   # 启动
"$HOME/Desktop/qq-bot/stop.command"                                    # 停止桥接
```

### 7.2 状态与日志

```bash
TOKEN=$(python3 -c "import json;print(json.load(open('$HOME/Desktop/qq-bot/surfcore/config.json'))['consoleToken'])")
curl -s -H "x-console-token: $TOKEN" http://127.0.0.1:3100/api/status | python3 -m json.tool
tail -f "$HOME/Desktop/qq-bot/surfcore/state/bridge.log"
```

### 7.3 备份

需要备份的目录（都不在 git 仓库里）：

| 路径 | 内容 |
| --- | --- |
| `surfcore/config.json` | 配置（含令牌，注意保密） |
| `~/.dsh/surfcore/characters/` | 角色/人设/记忆卡 |
| `~/.dsh/surfcore/backups/` | 自动备份 |
| `surfcore/state/stickers.json` | 表情库 |

### 7.4 更新

```bash
cd macos-dsh-qq-bot && git pull
# 重新安装（保留 config.json 与记忆）
OWNER_QQ=<你的QQ> bash scripts/install.sh --dir "$HOME/Desktop/qq-bot"
```

上游更新后补丁可能漂移，按 `install.sh` 的提示处理冲突。

### 7.5 迁移到新机器

1. 新机器按第 1 章安装
2. 把旧机器的 `config.json`、`~/.dsh/surfcore/characters/`、`state/stickers.json` 拷过去
3. 重启桥接与 DSH

### 7.6 合盖保持运行（可选）

```bash
sudo pmset -a disablesleep 1   # 合盖不休眠（屏幕仍熄）
sudo pmset -a disablesleep 0   # 恢复
```

> 重启后可能复位；要持久化需 LaunchDaemon 开机重申。注意散热与耗电。

### 7.7 卸载

```bash
bash scripts/uninstall.sh --dir "$HOME/Desktop/qq-bot/surfcore" --remove-files
```

---

## 8. 排障速查

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| QQ 有图标无窗口 | `--no-sandbox` 下 QQ 7.0.2 不建窗 | 机器人无窗口正常；自己用副本（第 6 章） |
| 桥接 403 / `dshReady:false` | DSH 桌面端拒绝非渲染进程 | `cordis.patch.yml` 设 `openBrowser:true` |
| 3000/3001 不开 | QQ 没带 `--no-sandbox`，或没登录，或 OneBot 配置没落对目录 | 检查启动参数/登录/配置路径，改完重启 QQ |
| 扫码 `Login Error, ErrType:1 ErrCode:1` | 腾讯风控 | 同 IP（手机热点）、等 10–30 分钟、换常登录账号 |
| 设置页找不到 SurfCore | `package.json` 缺 `"./package.json"` 导出 | 应用补丁 0003 后重启 DSH |
| 桥接重启变退出 | mac 无守护进程 | 补丁 0004 已修；或手动重启 |
| 表情库被清空 | 换号同步覆盖 | 补丁 0004 改为并集合并 |
| 桌宠安装卡住 | zip 反斜杠+GBK 文件名 | 补丁 0002 的纯 Node 解压 |
| 语音没反应 | 没装语音包或工具没开 | 设置 → 语音 → 启动；扩展里打开语音工具 |
| 记忆太多/太杂 | 容量或内容问题 | 设置 → 记忆 → 重置/清空指定范围 |

---

## 9. 安全与合规

- **QQ 自动化可能违反腾讯用户协议**，账号可能被风控、限速或封禁；请用**小号**，风险自担。
- 本仓库不提供账号、凭据、预登录状态或绕过风控的方法。
- `config.json` 含令牌，**不要提交到 git、不要发给人**。
- 聊天内容与记忆都在本机（`~/.dsh/surfcore/`、`surfcore/state/`），不会上传到本仓库。
- 想清除数据：设置 → 记忆 → 重置；再删 `~/.dsh/surfcore/characters/<角色>/memory/`。

---

## 10. 命令速查

```bash
# 安装 / 更新
OWNER_QQ=<你的QQ> bash scripts/install.sh --dir "$HOME/Desktop/qq-bot"
bash scripts/setup-dsh-plugin.sh --dir "$HOME/Desktop/qq-bot/surfcore"

# NapCat / 双开
bash scripts/setup-napcat.sh
bash scripts/setup-second-qq.sh

# 启停
bash scripts/start-surfcore.sh --dir "$HOME/Desktop/qq-bot/surfcore"
"$HOME/Desktop/qq-bot/stop.command"

# 状态
TOKEN=$(python3 -c "import json;print(json.load(open('$HOME/Desktop/qq-bot/surfcore/config.json'))['consoleToken'])")
curl -s -H "x-console-token: $TOKEN" http://127.0.0.1:3100/api/status | python3 -m json.tool

# OneBot 自测
curl -s -X POST -H 'content-type: application/json' \
  -H "authorization: Bearer <OneBot令牌>" -d '{}' \
  http://127.0.0.1:3000/get_login_info
```
