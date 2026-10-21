# 资源下载

## 当前可用路线

- **Minecraft 游戏文件、资源、支持库、版本列表**：复用上游 BMCLAPI 支持，新配置默认镜像优先，仍保留官方源回退。已经保存的用户偏好不会被覆盖。
- **Mod、Modrinth 整合包、资源包、光影**：通过 Modrinth 官方 API 搜索、获取版本，通过平台给出的 CDN 地址下载。公开内容无需 Microsoft 登录或 Modrinth API Token。
- **CurseForge**：集成暂时关闭。“可用来源”只搜索 Modrinth，CurseForge 选项隐藏；后台本地 Mod 识别、更新、导出也跳过该来源。底层直接请求与 HTTP Header 签名入口都会拒绝访问该 API；即使设置 `PCL_CURSEFORGE_API_KEY` 也不能启用。以后需要明确恢复集成，不能仅靠放入一个 Key 恢复。
- **仅在 CurseForge 发布的内容**：可从项目网页按作者允许的方式手动下载。CF 格式整合包的自动安装暂时关闭，会在解压前给出明确提示；没有平台下载地址时，不推测文件 CDN 地址。已有的游戏文件不会被删除。

MCIM 的维护者已公告暂停 API 与文件服务，本次检查旧接口返回 502。
不要把游戏文件的 BMCLAPI 镜像误认为 CurseForge API 的替代服务。
当前保留 `DlSourceModGet` 调用接口，但不再生成失效的 MCIM 地址；社区资源设置页也不再提供失效的镜像选项。

下载和账号权限互不替代。本修改不改变正版所有权检查，也不会解决仍需审核的 Minecraft Services 登录权限。
未关闭 TLS、文件尺寸或散列校验；未使用其他启动器的 API Key 或应用身份。

## 复现检查

先构建，再使用 Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PublicBuild.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Downloads.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Downloads.ps1 -Online
```

离线检查加载实际编译程序集，验证资源源选择、分页停止条件、CurseForge 关闭状态、下载地址解析以及两种登录模式的独立会话检查。
`-Online` 额外在工作线程调用实际编译的 `DlModRequest` HTTP 请求入口，并读取 BMCLAPI 版本列表、版本元数据与小型支持库，读取 Modrinth 的四类搜索结果、Fabric API 的版本元数据并下载一个样本。
样本使用运行时的平台元数据核对尺寸和 SHA-1，单次响应有 8 MiB 上限；所有样本及结果仅写到被 Git 忽略的 `artifacts/download-tests/`。
不启动 WPF 窗口，不运行下载的 JAR，不安装到现有游戏目录，不修改用户代理设置或账号信息。

这些检查**不是完整游戏安装、所有整合包依赖或登录/游玩端到端测试**。
公共服务状态、镜像同步进度和项目分发许可可能变化；不承诺所有资源均可下载。

## 服务文档

- [BMCLAPI 文档](https://bmclapidoc.bangbang93.com/)
- [Modrinth API：认证、限流与 User-Agent](https://docs.modrinth.com/api/)
- [MCIM 服务状态公告](https://github.com/mcmod-info-mirror/mcim-rust-api)
