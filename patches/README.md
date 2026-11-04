# Patches

> 本目录的补丁是对上游 MIT 代码的修改，按仓库根目录 [LICENSE](../LICENSE) 的 MIT 条款发布；
> 上游版权与来源见 [NOTICE.md](../NOTICE.md)。

对 `Mieksido/surfcore`（v0.8.8 / `0deb826`）的补丁，按顺序应用：

```bash
git clone https://github.com/Mieksido/surfcore.git
cd surfcore
git checkout 0deb826
for p in ../patches/*.patch; do git apply "$p"; done
```

| 补丁 | 内容 |
| --- | --- |
| `0001-node-path-macos.patch` | Electron 内查找 Node 时支持 mac 路径（便携 Node、Homebrew、`SURFCORE_NODE`） |
| `0002-pet-electron-macos.patch` | 桌宠宿主：Electron 按平台取可执行文件、下载地址按平台拼、纯 Node 解压（反斜杠 + GBK 文件名兼容） |
| `0003-launcher-macos.patch` | mac 上 NapCat WebUI 端口、`open` 启动 QQ、`.app` 检测、`package.json` exports 修复（否则 DSH 客户端模块被跳过） |
| `0004-bridge-macos-fixes.patch` | 桥接：重启守护、表情库合并、表情包 owner-only、小黄脸中文名、入站语音转写、视觉输入、主人豁免 Token 防爆破 |
| `0005-persona-layers.patch` | 人格分层独立预算（核心不再吃掉语气/场景/日常）、身份去重、B站/桌宠接入分层、`socialV2.prompt` 可覆盖「积极性/反AI味」 |


