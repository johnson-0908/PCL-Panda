# PCL2复活版（第三方修改版）

**本项目由 [johnson-0908](https://github.com/johnson-0908) 基于 PCL 公开源码独立修改，
不是 PCL、Mojang 或 Microsoft 官方发行版，与 PCL CE 无关。**

原作者：**龙腾猫跃（LTCat）**。感谢原作者与所有上游贡献者。
[原版 PCL](https://github.com/Meloong-Git/PCL) · [赞助原作者](https://meloong.com/afd/a/LTCat)

## 当前状态

这是开发中的第三方公开源码版本；二进制可测试，但不代表已经通过服务审核。

| 项目 | 状态 |
| --- | --- |
| Microsoft 公共客户端应用 | 已注册并配置 Client ID；云端显示名未随本次本地更名调整 |
| Minecraft Services AppID | **2026-10-21 已提交申请，等待审核，尚未获批** |
| CurseForge | **API 申请已提交；集成暂时关闭，社区资源使用 Modrinth** |
| 正版登录与真实游戏启动 | **尚未完成端到端验证，不承诺现在即可登录游玩** |
| 发布内容 | 源代码、构建/测试/发布脚本及 GitHub Release 测试包 |

注册 Microsoft 应用或设备码接口返回成功，不代表已经获得 Minecraft API 权限。
审批通过后还需用持有游戏的账号完成实际测试。

本修改版计划免费提供、无广告、无收费功能。目前没有盈利计划；保留的原作者赞助链接不属于本项目的收入。

## 修改内容

- 标明第三方修改版身份，在设置页保留原作者首位署名、赞助链接，默认使用蓝色界面。
- 界面、窗口标题与程序产品信息统一显示为「PCL2复活版」。为兼容现有账号、配置和资源引用，内部 `PCLPanda` 标识、程序集/EXE 文件名与 GitHub 地址保持不变。
- 使用独立 `PCLPanda` 配置范围、单实例标识；建议独立运行目录。
- 支持 Microsoft 正版登录与用户主动选择的离线登录。正版登录的缓存会话仍在线校验所有权和 Java Profile；
  校验失败不会自动改为离线。两种会话分开检查，不导出独立启动脚本。
- 配置自己的公共 Client ID，不复用其他启动器的私有凭据。
- 下载功能在源码构建中可用；不绕过账号所有权或服务器端 API 审批。
- 已删除“更多”模块、内置帮助及百宝箱空实现；设置页仅保留简要许可与来源。首次协议仍需用户主动确认。
- 个性化直接提供本地配色与自定义色调、饱和度、渐变、亮度，无赞助遮罩。配色是本分支独立实现，不是上游闭源主题特效。
- CurseForge Key 仅从本机环境读取，不硬编码、不向资源 CDN 附加 Key。
- 新配置默认优先使用 BMCLAPI 下载游戏文件、支持库与版本列表，保留官方源回退。
- 社区资源使用 Modrinth 官方 API/CDN；暂时关闭 CurseForge（即使本机有 Key 也不会启用），不再请求已暂停的 MCIM 镜像。

详见 [资源下载说明](docs/DOWNLOADS.md)、[认证及隐私说明](docs/AUTHENTICATION.md)、[界面修改说明](docs/INTERFACE.md)与[更新及发布说明](docs/UPDATES.md)。

## 下载与更新

从[本仓库 Releases](https://github.com/johnson-0908/PCL-Panda/releases/latest)下载 `PCL2-Revived-win-x64.zip`，
完整解压到可写目录，运行 `Plain Craft Launcher 2.exe`（不要只取 EXE）。
启动器内置本仓库 GitHub 更新源，不会更新回原版 PCL 或 CE。

启动时仅后台检查，有新版本时给出非模态提示；可在「设置 → 其他」关闭自动检查。
点击「检查更新」后自行确认下载，再确认重启安装。更新使用 SHA-256 和逐文件清单校验，
只替换白名单内的程序文件，保留账号、配置及游戏数据；只保留一份被后续更新覆盖的回滚备份。
GitHub 无法连接或限流时不影响启动器使用，可以从发布页手动下载。

首次公开包的独立发行版本为 `1.0.0`，不是上游 PCL 的版本号；Minecraft AppID 审批和正版登录仍需单独验证。

## Windows 构建

需要 Visual Studio 2022 的 **.NET 桌面开发**组件、.NET Framework 4.8 目标包、
.NET SDK 9，以及 Python 3（源码发布检查）。MeloongCore 源码已随仓库包含，无需子模块初始化。

```powershell
git clone https://github.com/johnson-0908/PCL-Panda.git
cd PCL-Panda
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PublicBuild.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Downloads.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-OfflineLogin.ps1
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\Test-Interface.ps1
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\Test-LaunchDashboard.ps1
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\Test-Branding.ps1
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\Test-Updates.ps1
python .\scripts\audit_public.py
```

固定输出：`artifacts/builds/launch-dashboard/Plain Craft Launcher 2.exe`，后续构建在原目录更新，不再按修改内容新建版本目录。
测试脚本默认使用同一个目录。构建只更新程序文件，不清理其中的游戏、存档和个人配置。
不要直接复用或打包一个已经登录过的运行目录。测试脚本不启动程序，也不操作账号。
编译成功不等于 Microsoft/Xbox/Minecraft 登录或实际游戏启动已通过验证。

若该目录的启动器正在运行，构建脚本会提示先正常关闭，不会强制结束进程或自动生成第二份程序。
仅在确需隔离构建时显式传入 `-OutputDirectory`，对应测试需传入相同的 `-BinaryDirectory`。

`PCL_MS_CLIENT_ID` 可用于开发者自己的应用标识覆盖；
`PCL_CURSEFORGE_API_KEY` 仅预留给获授权的本地 API 配置，当前关闭状态下不能启用 CurseForge。**不要提交 API Key 或登录令牌。**

## 许可、来源与反馈

PCL 使用其自身的《PCL 分发有限许可》和《PCL 存储库合理使用指南》，
不是 MIT/Apache 等通用宽松许可证。本项目是**公开源码（source-available）**的派生版本，
不扩大上游授权范围；继续保留并遵守 [LICENCE](LICENCE)。
MeloongCore 的 Apache-2.0 许可单独保留，其他第三方资源依其各自条款。
来源版本和变更记录见 [PROVENANCE.md](PROVENANCE.md)。

本修改版的问题请提交到 [本仓库 Issues](https://github.com/johnson-0908/PCL-Panda/issues)，
不要直接向原版或 PCL CE 仓库报告本修改版问题。报告前移除令牌、账号、游戏存档及本机路径。
