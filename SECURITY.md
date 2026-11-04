# Security

## 本仓库不会收集任何数据

安装脚本只在本地运行，不发送任何遥测、账号或聊天内容。

## 凭据处理

- `config.json` 由安装脚本在你本机生成，**不要提交到 git**（已在 `.gitignore`）
- 需要你填写的敏感项：
  - `ownerQQ`：你的 QQ 号
  - `consoleToken`：桥接控制台令牌（`openssl rand -hex 16` 生成）
  - `snowluma.accessToken`：OneBot 令牌（本地使用）
- 聊天记忆、会话、二维码、日志都在 `surfcore/state/`、`surfcore/characters/` 与 `~/.dsh/` 下，**不属于本仓库**

## 报告问题

请勿在 issue 里粘贴真实 QQ 号、令牌、聊天记录或带用户名的路径。用占位符代替。
