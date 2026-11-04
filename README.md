# macOS DSH QQ Bot

> 在 macOS（Apple Silicon）上跑一个住在 DeepSeek Harness（DSH）里的 QQ 机器人：
> **SurfCore 插件 + QQ（NapCat OneBot 11）+ 桥接**，附带 macOS 移植补丁、双开 QQ 脚本与桌宠适配。

本仓库**不包含** QQ 客户端、NapCat 二进制或任何账号数据。它是一组**补丁 + 安装脚本 + 文档**：
安装时从上游各自官方渠道下载，再应用本仓库的 macOS 适配。

## 架构

```
┌──────────────────────────────┐
│  DeepSeek Harness (DSH)      │  ← 宿主（Electron 桌面版 / Web）
│  ├─ surfcore 插件（本仓库补丁）│     人设 / 记忆 / QQ 工具 / 设置页
│  └─ 桥接 bridge.js (:3100)    │     聊天调度 / 提示词 / 会话
└──────────────┬───────────────┘
               │ OneBot 11 (HTTP :3000 / WS :3001)
┌──────────────┴───────────────┐
│  QQ.app + NapCat（官方分发）   │  ← 必须 --no-sandbox 启动才能注入
└──────────────────────────────┘
```

## 前置条件

- macOS 13+（Apple Silicon 建议；本仓库在 macOS 26 / QQ 7.0.2 上验证）
- DeepSeek Harness Desktop 2.x（[下载](https://github.com/anywhere-labs/deepseek-harness-desktop)）
- QQ macOS 客户端（腾讯官网，**不随本仓库分发**）
- NapCat（[官方 Release](https://github.com/NapNeko/NapCatQQ/releases)，**不随本仓库分发**）
- Node.js ≥ 22.13
- 一个用于机器人的 QQ 账号（**建议小号**）和一个大号（你自己用）

## 快速开始

```bash
git clone https://github.com/Shaoji-Lumine/macos-dsh-qq-bot.git
cd macos-dsh-qq-bot
bash scripts/install.sh --dir "$HOME/Desktop/qq-bot"
```

安装脚本会：下载 SurfCore → 应用 `patches/` → 装依赖 → 生成 `config.json`（交互式填 ownerQQ / consoleToken）→ 生成启动脚本。

然后按 [`docs/QUICKSTART.md`](docs/QUICKSTART.md)：

1. `scripts/setup-napcat.sh` 安装 NapCat 并让 QQ 以 `--no-sandbox` 启动
2. `scripts/start-surfcore.sh` 启动机器人（无窗口）
3. `scripts/setup-second-qq.sh` 生成「QQ大号」副本（有窗口，你自己聊天用）

## 仓库结构

```
patches/               对上游 SurfCore 的 macOS/增强补丁
scripts/
  install.sh           主安装（clone 上游 + 打补丁 + 配置）
  setup-napcat.sh      NapCat 安装指引/下载
  setup-second-qq.sh   复制 QQ.app 实现大小号同时在线
  start-surfcore.sh    启动机器人（QQ + 桥接）
  uninstall.sh         卸载
config/                脱敏配置模板
docs/                  快速开始 / 排障 / 移植笔记
```

## 已适配的问题（详见 docs/TROUBLESHOOTING.md）

- macOS 无系统 Node → 便携 Node / Homebrew 路径探测
- 桥接与 DSH 之间的 `openBrowser` 围栏（403）
- 桥接重启在 mac 上变「关机」→ 守护式重启
- 表情库在换号时被清空 → 并集合并
- 入站小黄脸数字 id → 中文名；入站语音 → `fetch_ptt_text` 转写
- 视觉输入：显式允许图片（deepseek-flash 可看图）
- 和主人对话豁免 Token 防爆破（次数/间隔/条数）
- 桌宠 Electron 运行时按平台选择（mac 用 `Electron.app/.../Electron`）
- QQ 表情包 zip 是反斜杠 + GBK 文件名 → 纯 Node 解压（`unzipWithNode`）
- **QQ 带 `--no-sandbox` 不创建窗口** → 双开方案（`setup-second-qq.sh`）

## 风险与合规声明

- **QQ 自动化可能违反腾讯用户协议**，账号可能被风控、限制或封禁，风险由使用者自行承担。
- 本仓库不提供账号、凭据、预登录状态或任何「绕过风控」的方法。
- 上游 SurfCore 为 **MIT**；本仓库补丁同样以 MIT 发布，保留上游版权声明。
- 第三方（QQ、NapCat、桌宠 surfpet）版权归各自作者，本仓库只包含适配代码与文档。

## License

MIT，见 [LICENSE](LICENSE) 与 [NOTICE.md](NOTICE.md)。
