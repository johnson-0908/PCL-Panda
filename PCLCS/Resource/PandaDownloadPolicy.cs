using System;

namespace PCLCS
{
    /// <summary>Availability of public download services, independent of game login.</summary>
    public static class PandaDownloadPolicy
    {
        // Temporarily disabled for this build; a local environment key cannot enable it.
        public static readonly bool CurseForgeEnabled = false;
        public const string CurseForgeDisabledMessage =
            "CurseForge 集成已暂时关闭，请使用 Modrinth，或从项目网页手动下载资源。";
        public const string CurseForgeKeyRequired =
            "CurseForge API Key 尚未配置。请先使用 Modrinth 下载资源，或从 CurseForge 项目网页手动下载；配置获授权的 Key 后重启启动器。";

        public static bool HasCurseForgeKey(string key)
        {
            return !string.IsNullOrWhiteSpace(key);
        }

        public static bool IsCurseForgeAvailable(string key)
        {
            return CurseForgeEnabled && HasCurseForgeKey(key);
        }

        public static string GetCurseForgeUnavailableReason(string key)
        {
            if (!CurseForgeEnabled) return CurseForgeDisabledMessage;
            return HasCurseForgeKey(key) ? "" : CurseForgeKeyRequired;
        }

        public static bool IsCurseForgeApi(string url)
        {
            Uri endpoint;
            return Uri.TryCreate(url, UriKind.Absolute, out endpoint)
                && string.Equals(endpoint.Host, "api.curseforge.com", StringComparison.OrdinalIgnoreCase);
        }

        public static int GetAvailablePlatforms(int requested, string curseForgeKey)
        {
            // ResourcePlatforms: CurseForge = 1, Modrinth = 2, Any = 3.
            // Do not replace an explicitly CF-only request with unrelated Modrinth results.
            return IsCurseForgeAvailable(curseForgeKey) ? requested : requested & ~1;
        }

        public static string GetUserAgent(string version)
        {
            return LauncherBranding.UserAgentProduct + "/" + version + " (+https://github.com/johnson-0908/PCL-Panda)";
        }
    }
}
