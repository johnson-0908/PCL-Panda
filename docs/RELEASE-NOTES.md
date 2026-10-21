# PCL2复活版 1.0.0（第三方修改版）

首个公开测试包，基于 PCL 公开源码独立修改，非原版 PCL、PCL CE、Mojang 或 Microsoft 官方产品。

- 新增本仓库 GitHub 更新：启动时仅提醒；用户确认下载和重启，SHA-256/文件清单校验，单份备份和失败回滚。
- 统一 PCL2复活版名称，新增启动页游戏空间，精简“更多”模块及重复提示。
- 本地个性化配色开放，保留原作者署名、来源和许可证。
- 支持显式离线模式；Microsoft 认证仍检查正版权限，不从登录失败自动降级。
- Minecraft 文件默认 BMCLAPI 优先并保留官方回退；社区资源使用 Modrinth；CurseForge 暂停。

## 使用

下载 `PCL2-Revived-win-x64.zip`，完整解压，运行 `Plain Craft Launcher 2.exe`。
**不要只复制 EXE，也不要覆盖/删除自己的 `.minecraft` 或 `PCL` 配置目录。**
未来更新入口：设置 → 其他 → 检查更新。离线无法获取更新时仍可使用已安装的启动器。

## 当前限制

- Microsoft 应用已配置，但 Minecraft AppID 审核尚未确认通过；正版登录/完整游戏启动不作为已验证承诺。
- 这是测试发行，更新助手暂未代码签名。更新弹窗、用户实际重启体验及真实游戏需手动测试。
- 源码沿用 PCL 原始有限许可与指南，不改为 MIT/Apache；MeloongCore 的许可另附。

原作者：龙腾猫跃（LTCat）。来源、归属及修改说明见仓库 README、PROVENANCE 和 LICENCE。
