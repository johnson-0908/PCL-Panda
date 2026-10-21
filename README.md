# PCL 熊猫启动器（第三方修改版）

**本项目由 [johnson-0908](https://github.com/johnson-0908) 基于 PCL 公开源码独立修改，
不是 PCL、Mojang 或 Microsoft 官方发行版，与 PCL CE 无关。**

原作者：**龙腾猫跃（LTCat）**。感谢原作者与所有上游贡献者。
[原版 PCL](https://github.com/Meloong-Git/PCL) · [赞助原作者](https://meloong.com/afd/a/LTCat)

## 当前状态

这是开发中的公开源码预览，不是已通过服务审核的正式发行版。

| 项目 | 状态 |
| --- | --- |
| Microsoft 公共客户端应用 | 已注册「熊猫启动器」，已配置 Client ID |
| Minecraft Services AppID | **尚未获批，正在准备审核申请** |
| CurseForge API Key | **尚未配置，API 功能可能返回 403** |
| 正版登录与真实游戏启动 | **尚未完成端到端验证，不承诺现在即可登录游玩** |
| 发布内容 | 源代码及本地构建、检查脚本；暂无正式二进制发行包 |

注册 Microsoft 应用或设备码接口返回成功，不代表已经获得 Minecraft API 权限。
审批通过后还需用持有游戏的账号完成实际测试。

## 修改内容

- 标明第三方修改版身份，保留原作者首位署名、赞助链接及蓝色界面。
- 使用独立 `PCLPanda` 配置范围、单实例标识；建议独立运行目录。
- 公共版仅支持 Microsoft 正版登录。缓存会话同样在线校验所有权和 Java Profile；
  校验失败停止启动，不回退离线登录，不导出独立启动脚本。
- 配置自己的公共 Client ID，不复用其他启动器的私有凭据。
- 下载功能在源码构建中可用；不绕过账号所有权或服务器端 API 审批。
- 服务审批说明放在关于页，不重复弹出源码版功能说明；首次协议仍需用户主动确认。
- CurseForge Key 仅从本机环境读取，不硬编码、不向资源 CDN 附加 Key。

详见 [认证与隐私说明](docs/AUTHENTICATION.md)。

## Windows 构建

需要 Visual Studio 2022 的 **.NET 桌面开发**组件、.NET Framework 4.8 目标包、
.NET SDK 9，以及 Python 3（源码发布检查）。MeloongCore 源码已随仓库包含，无需子模块初始化。

```powershell
git clone https://github.com/johnson-0908/PCL-Panda.git
cd PCL-Panda
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PublicBuild.ps1
python .\scripts\audit_public.py
```

输出：`Plain Craft Launcher 2/bin/Plain Craft Launcher 2.exe`。
不要直接复用或打包一个已经登录过的运行目录。测试脚本不启动程序，也不操作账号。
编译成功不等于 Microsoft/Xbox/Minecraft 登录或实际游戏启动已通过验证。

`PCL_MS_CLIENT_ID` 可用于开发者自己的应用标识覆盖；
`PCL_CURSEFORGE_API_KEY` 仅用于获授权的本地 API 配置。**不要提交 API Key 或登录令牌。**

## 许可、来源与反馈

PCL 使用其自身的《PCL 分发有限许可》和《PCL 存储库合理使用指南》，
不是 MIT/Apache 等通用宽松许可证。本项目是**公开源码（source-available）**的派生版本，
不扩大上游授权范围；继续保留并遵守 [LICENCE](LICENCE)。
MeloongCore 的 Apache-2.0 许可单独保留，其他第三方资源依其各自条款。
来源版本和变更记录见 [PROVENANCE.md](PROVENANCE.md)。

本修改版的问题请提交到 [本仓库 Issues](https://github.com/johnson-0908/PCL-Panda/issues)，
不要直接向原版或 PCL CE 仓库报告本修改版问题。报告前移除令牌、账号、游戏存档及本机路径。
