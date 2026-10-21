# GitHub 更新与发布

## 用户操作

更新源固定为 `johnson-0908/PCL-Panda` 的 [GitHub Releases](https://github.com/johnson-0908/PCL-Panda/releases)。
使用 GitHub 官方 [latest release API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)，
不需要用户登录 GitHub，不内置 GitHub Token，不使用上游更新服务器或第三方代理。

1. 「设置 → 其他 → 启动时检查新版本」默认启用。启动只检查一次，有新版时仅非模态提示，不弹窗、不下载。
2. 点击「检查更新」查看版本说明，自行确认「下载更新」。
3. 下载及校验完成后，再确认「重启安装」。稍后/取消不触发退出时暗中更新。
4. 等待游戏、启动和下载任务结束后，启动器保存配置并退出；独立 PowerShell 助手等待原进程正常退出，覆盖原目录后重启。
5. 网络失败、无 Release、GitHub 限流、校验失败时不替换现有程序。可以从本仓库发布页手动下载整个 ZIP。

仅支持 Windows、.NET Framework 4.8 和系统自带 Windows PowerShell 5.1。
保持 `Plain Craft Launcher 2.exe` 文件名，完整解压发布包；不要把程序放在只读目录或联接/符号链接路径中。
公开发行版本从 `1.0.0` 开始，使用 `vX.Y.Z` 标签，仅跟随非 draft、非 prerelease 的发行包；同版/降级不安装。
这里的“发行”仅表示更新通道可用，不代表 Minecraft 服务审核已通过，也不代表完整游戏体验已验收。

## 完整性与数据边界

- 校验 GitHub API 返回的资产 `digest`（SHA-256）及文件大小，再校验 ZIP 内清单的每个文件 hash/size。
- 只接受固定仓库的 HTTPS 资产地址；重定向限 GitHub 官方下载域名，限制次数、时间和大小。
- 拒绝额外文件、重复条目、路径穿越、未知清单版本、缺失程序文件和 reparse point。
- ZIP 仅含 `LauncherUpdate.AppFiles` 精确白名单及 `update-manifest.json`。不递归打包运行目录。
- 不含 `.minecraft`、账号缓存、`PCL/config.json`、API Key、日志、编译缓存和测试产物。
- 不请求管理员权限，不修改系统设置、不终止其他进程、不执行下载的发行说明。
- SHA-256 防止传输损坏和文件混入，但**不等同于代码签名**；信任根仍是本仓库 GitHub 账户、HTTPS 和发布者。

安装暂存固定为程序目录的 `PCL/Updates/pending`；成功后删除该次白名单暂存文件和下载 ZIP。
上一份程序只保留在 `PCL/Updates/backup`，后续更新覆盖，不按版本不断堆积独立运行包。
备份不包含游戏或账号。`PCL/Updates/result.json` 记录结果，错误详情在 `update-error.txt`，均只保存在本机。

普通复制/校验失败会自动恢复旧程序。断电/进程被外部终止无法保证自动回滚：
状态若为 `installing`/`rollback-failed`，后续更新会停止以保护原备份。确认启动器已关闭后可在安装目录运行：

```powershell
. .\Apply-Update.ps1 -LibraryOnly
$root = (Get-Location).Path
$backup = Join-Path $root 'PCL\Updates\backup'
$journal = Get-Content (Join-Path $backup 'journal.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Restore-UpdateBackup $root $backup $journal
Save-UpdateState (Join-Path $root 'PCL\Updates\result.json') 'rolled-back' '' 'Manual recovery completed.'
```

此操作校验备份并仅恢复白名单文件，不用删除整个 `PCL` 或 `.minecraft` 目录。

## 维护者发布下一版

1. 修改 `PCLCS/Update/LauncherUpdate.cs` 的 `CurrentVersion`，例如 `1.0.1`，更新 `docs/RELEASE-NOTES.md`。
2. 检查 diff、源码审计和许可证；只提交审阅过的源文件，推送到 `main`。不要上传整个运行文件夹。
3. 正常关闭正在运行的本地启动器。
4. 使用 Windows PowerShell 运行：

```powershell
# 默认只构建、测试、打包，不发布
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Publish-Release.ps1
# 确认源码已推送；使用维护者本地 gh 登录授权，明确发布
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Publish-Release.ps1 -Publish
```

可通过 `-CacheRoot` 复用本机依赖缓存；认证使用 GitHub CLI 自己的本地配置，不写入源码。
脚本要求干净工作区且本地 HEAD 已是远端 main，执行 7 组测试及源码审计，
精确打包到固定 `artifacts/release/PCL2-Revived-win-x64.zip`，不另建版本构建目录。
先上传 GitHub 草稿，回读服务器提供的 SHA-256/大小匹配后，才发布为 latest。
存在同名 Release/标签时停止，不重写已经发布的版本；失败留下的草稿须人工检查后处理。

发布产物为 ZIP 和 `SHA256SUMS.txt`；源代码由同一个提交和版本标签提供。
已安装该版本的用户无需重新 clone，之后就能通过启动器检测新的 Release。
仓库克隆或分支不会自动改变更新源；维护自己的分支须明确修改 Repository、客户端及安装助手的白名单/来源验证。

## 验证边界

`Test-Updates.ps1` 使用隔离的合成安装目录验证：版本比较、来源/大小/hash、ZIP 路径、重复条目、
文件锁、部分替换后的回滚、独立助手安装、唯一备份与运行数据保留；不启动真实游戏或登录账号。
`-Online` 额外检查真实 GitHub API。真实更新弹窗与个人环境的重启体验仍需用户手动验收。
