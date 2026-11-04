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
| `0006-bili-edge-macos.patch` | B站 扫码登录在 macOS 上也能找到 Edge（/Applications 路径） |
| `0004-bridge-macos-fixes.patch` | 桥接：重启守护、表情库合并、表情包 owner-only、小黄脸中文名、入站语音转写、视觉输入、主人豁免 Token 防爆破 |
| `0008-macos-autostart-qq.patch` | DSH 启动/自愈时自动拉起 QQ（macOS，带 `--no-sandbox`），与桥接一起自动启动 |
| `0010-dsh-fence-selfheal.patch` | DSH 改设置/装插件把 `openBrowser` 写回 false 时，插件自动修回（防 403 停摆） |
| `0009-close-after-send-failed.patch` | 收尾被「发送失败」永久卡死：工具发送成功也清零失败标记、失败 10 分钟过期、新增 `abandon` 明确放弃 |
| `0007-qq-bili-look.patch` | 给 QQ 侧加只读的 `qq_look_bilibili_video` 工具（读简介/字幕/弹幕/热评 + 抽帧九宫格；B站 未登录时返回提示） |
| `0005-persona-layers.patch` | 人格分层独立预算（核心不再吃掉语气/场景/日常）、身份去重、B站/桌宠接入分层、`socialV2.prompt` 可覆盖「积极性/反AI味」 |


