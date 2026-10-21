namespace PCLCS;

/// <summary>A read-only launch-page snapshot. Never scans files or reads accounts/settings.</summary>
public sealed class PandaLaunchDashboard
{
    public string Title { get; private set; } = "";
    public string Description { get; private set; } = "";
    public string Status { get; private set; } = "";
    public string SelectText { get; private set; } = "";
    public string Folder { get; private set; } = "";
    public bool HasError { get; private set; }
    public bool CanSelectVersion { get; private set; }
    public bool CanManageVersion { get; private set; }
    public bool CanInstall { get; private set; }
    public bool CanOpenFolder { get; private set; }

    public static PandaLaunchDashboard Create(bool isLoading, string? instanceName,
        string? description, string? folder, bool hasError = false, bool isLaunching = false)
    {
        bool hasInstance = !string.IsNullOrWhiteSpace(instanceName);
        bool busy = isLoading || isLaunching;
        return new PandaLaunchDashboard
        {
            Title = isLoading ? "正在读取游戏版本" : hasInstance ? instanceName! : "开始你的下一段冒险",
            Description = isLoading ? "正在扫描当前游戏目录，请稍候。" : hasInstance
                ? (string.IsNullOrWhiteSpace(description) ? "在左侧选择账户，然后启动游戏。" : description!)
                : "安装一个新版本，或从版本选择中添加已有游戏目录。",
            Status = isLoading ? "读取中" : isLaunching ? "启动中" : !hasInstance ? "尚未选择版本" : hasError ? "版本异常" : "已选择版本",
            SelectText = hasInstance ? "切换版本" : "选择已有版本",
            Folder = string.IsNullOrWhiteSpace(folder) ? "尚未设置游戏目录" : folder!,
            HasError = hasError && hasInstance && !isLoading,
            CanSelectVersion = !busy,
            CanManageVersion = hasInstance && !busy,
            CanInstall = !busy,
            CanOpenFolder = !string.IsNullOrWhiteSpace(folder)
        };
    }
}
