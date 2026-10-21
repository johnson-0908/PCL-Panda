using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;

namespace PCLCS;

/// <summary>Independent release channel. Never contacts the upstream PCL updater.</summary>
public static class LauncherUpdate
{
    public const string CurrentVersion = "1.0.0";
    public const string FileVersion = CurrentVersion + ".0";
    public const string VersionLabel = "PCL2复活版 " + CurrentVersion + " · GitHub 更新";
    public const string Repository = "johnson-0908/PCL-Panda";
    public const string ReleasesUrl = "https://github.com/" + Repository + "/releases";
    public const string ApiUrl = "https://api.github.com/repos/" + Repository + "/releases/latest";
    public const string AssetName = "PCL2-Revived-win-x64.zip";
    public const string ManifestName = "update-manifest.json";
    public const string ExeName = "Plain Craft Launcher 2.exe";
    public const long MaxPackageBytes = 128L * 1024 * 1024;
    public const long MaxExpandedBytes = 256L * 1024 * 1024;

    // Both packaging and installation use this exact allowlist. No directories, user files or wildcards.
    public static IReadOnlyList<string> AppFiles { get; } = Array.AsReadOnly(new[] {
        ExeName, ExeName + ".config", "PCLCS.dll", "MeloongCore.dll", "MeloongCore.Wpf.dll",
        "MeloongCore.deps.json", "Newtonsoft.Json.dll", "Ookii.Dialogs.Wpf.dll", "ThrottleDebounce.dll",
        "Microsoft.Win32.Registry.dll", "System.Security.AccessControl.dll", "System.Security.Principal.Windows.dll",
        "Apply-Update.ps1", "LICENCE", "MeloongCore-LICENSE.txt", "README.md", "PROVENANCE.md"
    });

    public static Version ParseVersion(string value)
    {
        if (!Regex.IsMatch(value ?? "", @"^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$") ||
            !Version.TryParse(value!.TrimStart('v'), out var version))
            throw new InvalidDataException("无效的发布版本号。");
        return version;
    }

    public static bool IsNewer(string available, string installed) => ParseVersion(available) > ParseVersion(installed);

    public static LauncherRelease? ParseRelease(string json)
    {
        var data = JObject.Parse(json);
        if (data.Value<bool?>("draft") != false || data.Value<bool?>("prerelease") != false) return null;
        string tag = data.Value<string>("tag_name") ?? "";
        string version = ParseVersion(tag).ToString();
        if (tag != "v" + version) throw new InvalidDataException("发布标签必须为 vX.Y.Z。");
        string page = ReleasesUrl + "/tag/" + tag;
        if (data.Value<string>("html_url") != page) throw new InvalidDataException("发布不属于当前仓库。");
        var assets = ((JArray?)data["assets"] ?? new JArray()).OfType<JObject>()
            .Where(a => a.Value<string>("name") == AssetName).ToArray();
        if (assets.Length != 1) throw new InvalidDataException("发布缺少唯一的完整更新包，请稍后重试。");
        var asset = assets[0];
        string url = ReleasesUrl + "/download/" + tag + "/" + AssetName;
        string digest = asset.Value<string>("digest") ?? "";
        long size = asset.Value<long?>("size") ?? 0;
        if (asset.Value<string>("browser_download_url") != url || asset.Value<string>("state") != "uploaded" ||
            !Regex.IsMatch(digest, "^sha256:[a-fA-F0-9]{64}$") || size <= 0 || size > MaxPackageBytes)
            throw new InvalidDataException("更新包的来源、大小或 SHA-256 校验信息无效，已停止更新。");
        string notes = data.Value<string>("body") ?? "";
        return new LauncherRelease(version, url, page, digest.Substring(7), size,
            notes.Length <= 1500 ? notes : notes.Substring(0, 1500) + "…");
    }

    public static LauncherRelease? CheckLatest()
    {
        try
        {
            using var response = OpenResponse(new Uri(ApiUrl));
            using var input = response.GetResponseStream();
            using var output = new MemoryStream();
            CopyBounded(input, output, 2 * 1024 * 1024);
            return ParseRelease(Encoding.UTF8.GetString(output.ToArray()));
        }
        catch (WebException ex) when ((ex.Response as HttpWebResponse)?.StatusCode == HttpStatusCode.NotFound)
        {
            ex.Response?.Dispose();
            return null; // A public repository with no release yet is not a fatal application error.
        }
    }

    public static bool IsAllowedNetworkUri(Uri uri) => uri.Scheme == "https" && uri.IsDefaultPort &&
        string.IsNullOrEmpty(uri.UserInfo) && string.IsNullOrEmpty(uri.Fragment) &&
        new[] { "api.github.com", "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com" }
            .Contains(uri.Host, StringComparer.OrdinalIgnoreCase);

    private static HttpWebResponse OpenResponse(Uri uri)
    {
        for (int redirect = 0; redirect < 6; redirect++)
        {
            if (!IsAllowedNetworkUri(uri)) throw new InvalidDataException("拒绝不受信任的更新下载地址。");
            var request = (HttpWebRequest)WebRequest.Create(uri);
            request.AllowAutoRedirect = false;
            request.UserAgent = "PCL2-Revived/" + CurrentVersion;
            request.Accept = uri.Host == "api.github.com" ? "application/vnd.github+json" : "application/octet-stream";
            if (uri.Host == "api.github.com") request.Headers["X-GitHub-Api-Version"] = "2022-11-28";
            request.Timeout = 20000;
            request.ReadWriteTimeout = 30000;
            var response = (HttpWebResponse)request.GetResponse();
            if ((int)response.StatusCode >= 300 && (int)response.StatusCode < 400)
            {
                var location = response.Headers["Location"];
                response.Dispose();
                if (string.IsNullOrEmpty(location)) throw new InvalidDataException("更新下载重定向缺少地址。");
                uri = new Uri(uri, location);
                continue;
            }
            if (response.StatusCode != HttpStatusCode.OK)
            {
                response.Dispose();
                throw new InvalidDataException("更新服务器返回了意外响应。");
            }
            return response;
        }
        throw new InvalidDataException("更新下载重定向次数过多。");
    }

    private static void CopyBounded(Stream input, Stream output, long limit)
    {
        byte[] buffer = new byte[65536];
        long total = 0;
        var timer = Stopwatch.StartNew();
        int count;
        while ((count = input.Read(buffer, 0, buffer.Length)) > 0)
        {
            total += count;
            if (total > limit || timer.Elapsed.TotalMinutes > 5) throw new InvalidDataException("更新下载超出大小或时间限制。");
            output.Write(buffer, 0, count);
        }
    }

    public static string Sha256(string file)
    {
        using var hash = SHA256.Create();
        using var stream = File.OpenRead(file);
        return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", "").ToLowerInvariant();
    }

    /// <summary>Reject junctions/symlinks in every existing path component before any write.</summary>
    public static void AssertSafePath(string path)
    {
        var current = Path.GetFullPath(path);
        while (!string.IsNullOrEmpty(current))
        {
            try
            {
                // GetAttributes can also detect a dangling reparse point; Exists alone cannot.
                if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                    throw new IOException("更新路径不能包含符号链接或目录联接。");
            }
            catch (FileNotFoundException) { }
            catch (DirectoryNotFoundException) { }
            current = Path.GetDirectoryName(current.TrimEnd(Path.DirectorySeparatorChar));
        }
    }

    public static string DownloadAndPrepare(LauncherRelease release, string targetDirectory)
    {
        string updates = Path.Combine(Path.GetFullPath(targetDirectory), "PCL", "Updates");
        AssertSafePath(updates);
        Directory.CreateDirectory(updates);
        string zip = Path.Combine(updates, "download.zip");
        AssertSafePath(zip);
        using (var response = OpenResponse(new Uri(release.DownloadUrl)))
        using (var source = response.GetResponseStream())
        using (var output = new FileStream(zip, FileMode.Create, FileAccess.Write, FileShare.None))
            CopyBounded(source, output, release.Size);
        return PreparePackage(zip, targetDirectory, release.Version, release.Sha256, release.Size);
    }

    // Also used by offline regression tests: all validation precedes extraction or application changes.
    public static string PreparePackage(string zipPath, string targetDirectory, string version, string sha256, long size)
    {
        ParseVersion(version);
        if (!Regex.IsMatch(sha256 ?? "", "^[a-fA-F0-9]{64}$") || size <= 0 || size > MaxPackageBytes ||
            new FileInfo(zipPath).Length != size || !Sha256(zipPath).Equals(sha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("更新包 SHA-256 或大小校验失败。");
        string stage = Path.Combine(Path.GetFullPath(targetDirectory), "PCL", "Updates", "pending");
        AssertSafePath(stage);
        var allowed = new HashSet<string>(AppFiles.Concat(new[] { ManifestName }), StringComparer.Ordinal);
        using var zip = ZipFile.OpenRead(zipPath);
        if (zip.Entries.Count != allowed.Count || zip.Entries.Sum(e => e.Length) > MaxExpandedBytes ||
            zip.Entries.Any(e => !allowed.Contains(e.FullName)) ||
            zip.Entries.Select(e => e.FullName).Distinct(StringComparer.OrdinalIgnoreCase).Count() != allowed.Count)
            throw new InvalidDataException("更新包包含重复、缺失、越界或不允许的文件。");
        var manifestEntry = zip.GetEntry(ManifestName)!;
        if (manifestEntry.Length > 65536) throw new InvalidDataException("更新清单过大。");
        JObject manifest;
        using (var reader = new StreamReader(manifestEntry.Open())) manifest = JObject.Parse(reader.ReadToEnd());
        var files = ReadManifest(manifest, version);
        foreach (var entry in zip.Entries.Where(e => e.FullName != ManifestName))
        {
            var info = files[entry.FullName];
            using var stream = entry.Open();
            using var hash = SHA256.Create();
            string actual = BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", "");
            if (entry.Length != info.Size || !actual.Equals(info.Hash, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("更新文件校验失败：" + entry.FullName);
        }
        Directory.CreateDirectory(stage);
        // Reuse one staging area; never enumerate/delete any game or account directory.
        foreach (var entry in zip.Entries)
        {
            string destination = Path.Combine(stage, entry.FullName);
            AssertSafePath(destination);
            entry.ExtractToFile(destination, true);
        }
        return stage;
    }

    private static Dictionary<string, (long Size, string Hash)> ReadManifest(JObject manifest, string version)
    {
        if (manifest.Value<int?>("schema") != 1 || manifest.Value<string>("version") != version ||
            manifest.Value<string>("repository") != Repository || manifest["files"] is not JArray entries)
            throw new InvalidDataException("更新清单版本或仓库不匹配。");
        var files = new Dictionary<string, (long, string)>(StringComparer.Ordinal);
        foreach (var entry in entries.OfType<JObject>())
        {
            string name = entry.Value<string>("name") ?? "";
            long length = entry.Value<long?>("size") ?? -1;
            string hash = entry.Value<string>("sha256") ?? "";
            if (!AppFiles.Contains(name) || files.ContainsKey(name) || length <= 0 || length > MaxExpandedBytes ||
                !Regex.IsMatch(hash, "^[a-fA-F0-9]{64}$")) throw new InvalidDataException("非法更新文件清单。");
            files.Add(name, (length, hash));
        }
        if (files.Count != AppFiles.Count || entries.Count != AppFiles.Count) throw new InvalidDataException("更新文件清单不完整。");
        return files;
    }

    public static void StartInstaller(string targetDirectory, string version)
    {
        ParseVersion(version);
        targetDirectory = Path.GetFullPath(targetDirectory).TrimEnd(Path.DirectorySeparatorChar);
        string updates = Path.Combine(targetDirectory, "PCL", "Updates");
        string worker = Path.Combine(updates, "worker.ps1");
        AssertSafePath(worker);
        string script = Path.Combine(targetDirectory, "Apply-Update.ps1");
        AssertSafePath(script);
        File.Copy(script, worker, true);
        string Quote(string text) => "\"" + text + "\"";
        using var parent = Process.GetCurrentProcess();
        var start = new ProcessStartInfo {
            FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
            Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + Quote(worker) +
                " -TargetDirectory " + Quote(targetDirectory) + " -ExpectedVersion " + Quote(version) +
                " -ParentProcessId " + parent.Id + " -ParentStartTicks " + parent.StartTime.ToUniversalTime().Ticks,
            WorkingDirectory = targetDirectory, UseShellExecute = false, CreateNoWindow = true
        };
        using var workerProcess = Process.Start(start) ?? throw new IOException("无法启动更新助手。");
    }
}

public sealed class LauncherRelease
{
    public string Version { get; }
    public string DownloadUrl { get; }
    public string PageUrl { get; }
    public string Sha256 { get; }
    public long Size { get; }
    public string Notes { get; }
    internal LauncherRelease(string version, string download, string page, string hash, long size, string notes)
    { Version = version; DownloadUrl = download; PageUrl = page; Sha256 = hash; Size = size; Notes = notes; }
}
