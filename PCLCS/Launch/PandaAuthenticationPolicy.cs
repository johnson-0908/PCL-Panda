using System;

namespace PCLCS
{
    /// <summary>
    /// Local validation only. Ownership must still be checked with Minecraft Services.
    /// </summary>
    public static class PandaAuthenticationPolicy
    {
        public const string MicrosoftLoginRequired =
            "PCL 熊猫启动器公开版仅支持 Microsoft 正版登录。请登录持有 Minecraft Java 版的账号。";

        public static bool IsAllowedLoginType(int loginType)
        {
            // PCL.ModLaunch.McLoginType.Ms
            return loginType == 5;
        }

        public static bool IsValidMicrosoftSession(string type, string accessToken, string uuid, string name)
        {
            Guid parsed;
            return type == "Microsoft" && !string.IsNullOrWhiteSpace(accessToken)
                && !string.IsNullOrWhiteSpace(name)
                && Guid.TryParseExact(uuid, "N", out parsed) && parsed != Guid.Empty;
        }

        public static bool ShouldSendCurseForgeKey(string url, string key)
        {
            Uri endpoint;
            return !string.IsNullOrWhiteSpace(key)
                && Uri.TryCreate(url, UriKind.Absolute, out endpoint)
                && endpoint.Scheme == Uri.UriSchemeHttps
                && endpoint.IsDefaultPort
                && string.IsNullOrEmpty(endpoint.UserInfo)
                && string.Equals(endpoint.Host, "api.curseforge.com", StringComparison.OrdinalIgnoreCase);
        }
    }
}
