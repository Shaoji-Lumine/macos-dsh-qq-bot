# TROUBLESHOOTING（macOS）

## QQ 有进程、菜单栏有名字，但没有窗口

原因：NapCat 注入要求 QQ 带 `--no-sandbox` 启动；而 QQ 7.0.2 在 macOS 26 上带这个参数**不创建窗口**。

对策：两份 QQ 分开用——
- 机器人：`/Applications/QQ.app` + `--no-sandbox`，无窗口后台跑
- 自己用：`scripts/setup-second-qq.sh` 生成 `/Applications/QQ大号.app`，正常启动有窗口

## 桥接返回 403 / `dshReady: false`

DSH 桌面端默认拒绝非渲染进程访问本机 HTTP。在 `~/.dsh/profiles/desktop/cordis.patch.yml`：

```yaml
- id: desktop-shell
  config:
    openBrowser: true
    networkExposure: loopback
```

重启 DSH。

## 桥接「重启」变成彻底退出

macOS 上没有 Windows 的守护进程，`/api/restart` 的旧实现会自杀。补丁 0004 已改为
spawn 一个 2 秒后启动的继任进程；如果没有补丁，手动重启：

```bash
pkill -f "node src/bridge.js"
cd <安装目录>/surfcore && nohup node src/bridge.js >/dev/null 2>&1 &
```

## 扫码报 `Login Error, ErrType:1 ErrCode:1`

腾讯风控，不是二维码过期。按顺序试：

1. 手机开热点，Mac 连热点（出口 IP 一致）再扫
2. 等 10–30 分钟（短时间多次失败会加重风控）
3. 换一个平时就在这台 Mac 登录过的账号

判断是风控还是过期：

```bash
grep -a "Login Error" /tmp/qq-napcat.log      # 有 = 风控
grep -a "登录服务已断开" /tmp/qq-napcat.log    # 只有 = 二维码自然过期
```

## OneBot 端口 3000/3001 不开

- QQ 是否带 `--no-sandbox` 启动？
- 是否已登录小号？（未登录时 NapCat 只开 WebUI 6099，不开 OneBot）
- NapCat 配置是否写到了**生效目录**（不是 `Documents/napcat`）？
- 改完配置要**重启 QQ** 才生效

## 表情/图片工具返回文字标签而不是图片

`socialV2.vision.imageInput` 应为 `"true"`（模型支持看图时）。
配置后仍降级，查看 `state/bridge.log` 是否有 `未声明 image 输入` 警告。

## 表情库换号后被清空

补丁 0004 已改成并集合并（`complete: false`），换号时保留本地库、拉空不覆盖。

## QQ 表情包 zip 解压失败 / 卡住（`write error (disk full?)`）

surfpet 的 zip 用反斜杠 + GBK 文件名，系统 `unzip` 会卡住、`ditto` 会产出 `assets\icon.png` 这种废名字。
补丁 0002 内置了纯 Node 解压（`unzipWithNode`），无需系统 unzip。

## DSH 里找不到 SurfCore 设置页

- 插件 `package.json` 的 `exports` 是否包含 `"./package.json"`（补丁 0003）
- DSH 重启后启动模块表里是否有 `surfcore`
- profile 的 `bundles` 与 `node_modules` 链接是否正确

## 桌宠（surfpet）

1. `npm install electron@45.0.0`（镜像 `ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/`）
2. 设置页填 Electron 路径：`.../node_modules/electron/dist/Electron.app/Contents/MacOS/Electron`
3. 安装包填官方 `pet-pack.zip`
4. 补丁 0002 让检测/下载/解压都按平台工作

## 合盖保持运行（可选）

```bash
sudo pmset -a disablesleep 1   # 合盖不休眠（屏幕仍会熄）
sudo pmset -a disablesleep 0   # 恢复
```

`disablesleep` 重启后可能被重置，需要持久化就用 LaunchDaemon 在开机时重新执行。
（注意散热与耗电，建议插电使用。）
