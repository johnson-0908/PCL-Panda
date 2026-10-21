using System;

namespace PCLCS
{
    /// <summary>
    /// Local session validation. Microsoft ownership is still checked with Minecraft Services.
    /// </summary>
    public static class PandaAuthenticationPolicy
    {
        public const string SupportedLoginRequired =
            "请选择 Microsoft 正版登录或离线登录。";

        public static bool IsAllowedLoginType(int loginType)
        {
            // PCL.ModLaunch.McLoginType.Legacy / Ms
            return loginType == 0 || loginType == 5;
        }

        public static bool IsValidMicrosoftSession(string type, string accessToken, string uuid, string name)
        {
            return type == "Microsoft" && !string.IsNullOrWhiteSpace(accessToken)
                && HasValidProfile(uuid, name);
        }

        public static bool IsValidLaunchSession(int loginType, string type, string accessToken, string uuid, string name)
        {
            if (loginType == 5) return IsValidMicrosoftSession(type, accessToken, uuid, name);
            // Explicit local mode only: a failed Microsoft login is never downgraded.
            return loginType == 0 && type == "Legacy" && HasValidProfile(uuid, name)
                && string.Equals(accessToken, uuid, StringComparison.OrdinalIgnoreCase);
        }

        private static bool HasValidProfile(string uuid, string name)
        {
            Guid parsed;
            return !string.IsNullOrWhiteSpace(name)
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
