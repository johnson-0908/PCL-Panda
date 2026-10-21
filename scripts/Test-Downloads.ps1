[CmdletBinding()]
param([switch]$Online, [string]$BinaryDirectory)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run with Windows PowerShell 5.1 (powershell.exe).' }
$root = Split-Path $PSScriptRoot -Parent
$bin = if ($BinaryDirectory) { [IO.Path]::GetFullPath($BinaryDirectory) } else { Join-Path $root 'artifacts\builds\launch-dashboard' }
$script:count = 0
function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:count++
}
# Load the built code, not a copy of the URL mapping. Do not start the WPF app.
Add-Type -AssemblyName System.Net.Http
[void][Reflection.Assembly]::LoadFrom((Join-Path $root 'Plain Craft Launcher 2\Resources\Newtonsoft.Json.dll'))
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $bin 'Plain Craft Launcher 2.exe'))
$keyField = $assembly.GetType('PCL.ModSecret', $true).GetField('CurseForgeAPIKey', [Reflection.BindingFlags]'Public,NonPublic,Static')
$savedKey = $keyField.GetValue($null)
$keyField.SetValue($null, '')
try {
    foreach ($url in @(
        'https://api.modrinth.com/v2/project/fabric-api',
        'https://staging-api.modrinth.com/v2/project/fabric-api',
        'https://cdn.modrinth.com/data/test/versions/test/file.jar',
        'https://api.curseforge.com/v1/mods/306612',
        'https://edge.forgecdn.net/files/1234/567/file.jar',
        'https://example.test/api.modrinth.com/file.jar'
    )) {
        Assert-True ([PCL.ModDownload]::DlSourceModGet($url) -eq $url) "Do not route to retired MCIM: $url"
    }
    Assert-True ([PCLCS.PandaDownloadPolicy]::GetAvailablePlatforms(3, '') -eq 2) 'Without a key, all sources means Modrinth'
    Assert-True ([PCLCS.PandaDownloadPolicy]::GetAvailablePlatforms(1, '') -eq 0) 'Do not silently substitute a CF-only query'
    Assert-True ([PCLCS.PandaDownloadPolicy]::GetAvailablePlatforms(2, '') -eq 2) 'Modrinth does not need a key'
    Assert-True ([PCLCS.PandaDownloadPolicy]::GetAvailablePlatforms(3, 'synthetic-test-key') -eq 2) 'CF stays disabled even when an environment key exists'
    Assert-True (-not [PCLCS.PandaDownloadPolicy]::CurseForgeEnabled) 'CF integration is explicitly switched off'
    Assert-True ([PCLCS.PandaDownloadPolicy]::GetAvailablePlatforms(3, '   ') -eq 2) 'Whitespace is not a configured key'
    $storage = New-Object PCL.ResourceSearcher+SearchResult
    $request = New-Object PCL.ResourceSearcher+SearchRequest -ArgumentList ([PCLCS.ResourceTypes]::Mod),$storage,40
    Assert-True ([int]$request.AvailableSources -eq 2) 'Real search request filters unavailable CF'
    Assert-True ($request.CanContinue) 'Modrinth initial page can load'
    Assert-True ($storage.CurseForgeTotal -eq 0) 'Unavailable CF cannot trigger repeated pagination'
    $storage.ModrinthTotal = 40
    $storage.ModrinthOffset = 40
    Assert-True (-not $request.CanContinue) 'Stop at the end of Modrinth results'
    Assert-True ([int]$request.Sources -eq 3) 'Preserve requested sources for loader equality'
    $blocked = $false
    try { [void][PCL.ModDownload]::DlModRequest('https://api.curseforge.com/v1/mods/306612', $null, $null, $null) }
    catch { $blocked = $_.Exception.ToString().Contains([PCLCS.PandaDownloadPolicy]::CurseForgeDisabledMessage) }
    Assert-True $blocked 'Disabled CF request fails locally with an actionable message'
    $keyField.SetValue($null, 'synthetic-test-key')
    $blocked = $false
    try { [void][PCL.ModDownload]::DlModRequest('https://api.curseforge.com/v1/mods/306612', $null, $null, $null) }
    catch { $blocked = $_.Exception.ToString().Contains([PCLCS.PandaDownloadPolicy]::CurseForgeDisabledMessage) }
    Assert-True $blocked 'A configured key cannot override the CF shutdown'
    $requestMessage = New-Object System.Net.Http.HttpRequestMessage
    $signer = $assembly.GetType('PCL.ModSecret', $true).GetMethod('SecretHeadersSign', [Reflection.BindingFlags]'Public,NonPublic,Static')
    $blocked = $false
    try { [void]$signer.Invoke($null, @('https://api.curseforge.com/v1/mods/306612', $requestMessage.psobject.BaseObject, $false)) }
    catch {
        $blocked = $_.Exception.ToString().Contains([PCLCS.PandaDownloadPolicy]::CurseForgeDisabledMessage)
        if (-not $blocked) { throw }
    }
    Assert-True $blocked 'HTTP signing boundary also blocks CF'
    Assert-True (-not $requestMessage.Headers.Contains('x-api-key')) 'Disabled CF never attaches its key'
    $requestMessage.Dispose()
    $keyField.SetValue($null, '')

    $fixture = '{"gameId":432,"id":1234567,"displayName":"Test","fileDate":"2026-01-01T00:00:00Z","releaseType":1,"downloadCount":1,"fileName":"test.jar","fileLength":123,"hashes":[],"downloadUrl":null,"gameVersions":["1.20.1","Fabric"]}'
    $data = [Newtonsoft.Json.Linq.JObject]::Parse($fixture)
    $version = [PCL.ResourceVersion]::FromPlatformJson($data, [PCLCS.ResourceTypes]::Mod)
    Assert-True (-not $version.DownloadAvailable) 'No guessed CDN URL when CF does not provide a download URL'
    $data['downloadUrl'] = [Newtonsoft.Json.Linq.JValue]::new('https://edge.forgecdn.net/files/1234/567/test.jar')
    $version = [PCL.ResourceVersion]::FromPlatformJson($data, [PCLCS.ResourceTypes]::Mod)
    Assert-True $version.DownloadAvailable 'Explicit CF download URL remains usable'
    Assert-True (-not ($version.DownloadUrls -match 'mcimirror')) 'CF downloads contain no retired mirror'
    $ua = [PCLCS.PandaDownloadPolicy]::GetUserAgent('test')
    $header = New-Object System.Net.Http.HttpRequestMessage
    $header.Headers.UserAgent.ParseAdd($ua)
    Assert-True ($ua.StartsWith('PCL2-Revived/') -and $ua.Contains('johnson-0908/PCL-Panda')) 'Identify this fork to API operators'
    $header.Dispose()
    $settings = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageSetup\Settings.vb') -Raw -Encoding UTF8
    foreach ($key in @('ToolDownloadSource', 'ToolDownloadVersion')) {
        Assert-True ($settings.Contains(('New Setting("{0}", 0,' -f $key))) "Mirror-first default: $key"
    }
    $search = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Modules\Resource\ResourceSearcher.vb') -Raw -Encoding UTF8
    Assert-True (-not $search.Contains('Request.Sources.HasFlagF(')) 'All search branches use available sources'
    $secret = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Modules\ModSecret.vb') -Raw -Encoding UTF8
    Assert-True ($secret.Contains('PandaDownloadPolicy.GetUserAgent(')) 'Real HTTP signing uses fork User-Agent'
    [xml]$resourcePage = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageDownload\Resource\PageResource.xaml') -Raw -Encoding UTF8
    $firstCard = $resourcePage.SelectSingleNode('/*/*[local-name()="StackPanel"]/*[1]')
    Assert-True ($firstCard.LocalName -eq 'MyCard' -and $firstCard.GetAttribute('Name', 'http://schemas.microsoft.com/winfx/2006/xaml') -eq 'PanAlways') 'Resource page starts with the search card, not a source banner'
    $bannerMembers = $assembly.GetType('PCL.PageResource', $true).GetMember('HintDownloadSources', [Reflection.BindingFlags]'Public,NonPublic,Instance')
    Assert-True ($bannerMembers.Length -eq 0) 'Compiled resource page has no download-source banner'
    $result = [ordered]@{Status='PASS'; Assertions=$script:count; LauncherStarted=$false; Online='NOT_RUN'; GameInstallAndLogin='NOT_TESTED'}

    if ($Online) {
        # Application_Startup normally installs an embedded-DLL resolver. Load only
        # the transport dependencies here, without executing application startup.
        foreach ($dll in @('ThrottleDebounce', 'System.Net.Http.Formatting', 'CacheCow.Common', 'CacheCow.Client.FileStore', 'CacheCow.Client')) {
            [void][Reflection.Assembly]::LoadFrom((Join-Path $root ("Plain Craft Launcher 2\Resources\$dll.dll")))
        }
        Add-Type -TypeDefinition @'
using System;
using System.Reflection;
using System.Threading;
public static class PandaDownloadTestWorker {
    public static object Request(MethodInfo method, string url) {
        object result = null;
        Exception failure = null;
        var thread = new Thread(() => {
            try { result = method.Invoke(null, new object[] { url, null, null, null }); }
            catch (Exception ex) { failure = ex; }
        });
        thread.IsBackground = true;
        thread.Start();
        if (!thread.Join(90000)) throw new TimeoutException("Launcher transport test exceeded 90 seconds.");
        if (failure != null) throw failure;
        return result;
    }
}
'@
        $out = Join-Path $root ('artifacts\download-tests\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        [void](New-Item -ItemType Directory -Path $out -Force)
        $client = New-Object System.Net.Http.HttpClient
        $client.Timeout = [TimeSpan]::FromSeconds(45)
        $client.DefaultRequestHeaders.UserAgent.ParseAdd($ua)
        $savedTemp = [PCL.ModBase]::PathTemp
        [PCL.ModBase]::PathTemp = Join-Path $out 'transport-cache\'
        $script:checks = New-Object 'System.Collections.Generic.List[object]'
        function Get-TestBytes([string]$Url, [string]$Name, [int]$MaxBytes = 8388608) {
            $response = $null
            try {
                $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
                [void]$response.EnsureSuccessStatusCode()
                if ($response.Content.Headers.ContentLength -gt $MaxBytes) { throw "Size limit exceeded: $Name" }
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $memory = New-Object IO.MemoryStream
                try {
                    $buffer = New-Object byte[] 16384
                    while (($n = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                        if ($memory.Length + $n -gt $MaxBytes) { throw "Size limit exceeded: $Name" }
                        $memory.Write($buffer, 0, $n)
                    }
                    $bytes = $memory.ToArray()
                } finally { $memory.Dispose(); $stream.Dispose() }
                $script:checks.Add([pscustomobject]@{Name=$Name; Status=[int]$response.StatusCode; Bytes=$bytes.Length})
                return ,$bytes
            } catch {
                throw [InvalidOperationException]::new("Online check failed: $Name ($Url)", $_.Exception)
            } finally { if ($null -ne $response) { $response.Dispose() } }
        }
        function Get-TestJson([string]$Url, [string]$Name) {
            $bytes = Get-TestBytes $Url $Name
            return [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        }
        function Save-VerifiedFile([string]$Url, [string]$Name, [string]$Sha1, [long]$Size) {
            $bytes = Get-TestBytes $Url $Name
            $algorithm = [Security.Cryptography.SHA1]::Create()
            try { $hash = -join ($algorithm.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) } finally { $algorithm.Dispose() }
            Assert-True ($bytes.Length -eq $Size) "$Name exact size"
            Assert-True ($hash -eq $Sha1) "$Name SHA-1 matches platform metadata"
            [IO.File]::WriteAllBytes((Join-Path $out $Name), $bytes)
            $script:checks.Add([pscustomobject]@{Name=($Name + '-integrity'); Bytes=$bytes.Length; ExpectedSha1=$Sha1; ActualSha1=$hash; Status='PASS'})
        }
        try {
            # Exercise the actual launcher HTTP transport and header signer without its UI.
            $method = $assembly.GetType('PCL.ModDownload', $true).GetMethod('DlModRequest')
            $project = [PandaDownloadTestWorker]::Request($method, 'https://api.modrinth.com/v2/project/fabric-api')
            Assert-True ($project['slug'].ToString() -eq 'fabric-api') 'Built launcher HTTP transport retrieves real Modrinth metadata'
            $script:checks.Add([pscustomobject]@{Name='built-launcher-resource-request'; Status='PASS'; Project=$project['slug'].ToString()})
            $manifest = Get-TestJson 'https://bmclapi2.bangbang93.com/mc/game/version_manifest.json' 'bmcl-version-list'
            $entry = $manifest.versions | Where-Object id -eq '1.20.1' | Select-Object -First 1
            Assert-True ($null -ne $entry) 'BMCL lists the sample Minecraft version'
            $metaUrls = @([PCL.ModDownload]::DlSourceLauncherOrMetaGet($entry.url))
            $metaUrl = $metaUrls | Where-Object { ([uri]$_).Host -eq 'bmclapi2.bangbang93.com' } | Select-Object -First 1
            Assert-True ($null -ne $metaUrl) 'Real launcher routing includes BMCL metadata'
            $metadata = Get-TestJson $metaUrl 'bmcl-version-metadata'
            $library = $metadata.libraries | Where-Object { $_.downloads.artifact.size -gt 1024 -and $_.downloads.artifact.size -lt 500000 } | Select-Object -First 1
            $artifact = $library.downloads.artifact
            $libraryUrl = @([PCL.ModDownload]::DlSourceLibraryGet($artifact.url)) | Where-Object { ([uri]$_).Host -eq 'bmclapi2.bangbang93.com' } | Select-Object -First 1
            Assert-True ($null -ne $libraryUrl) 'Real launcher routing includes BMCL library mirror'
            Save-VerifiedFile $libraryUrl 'sample-library.jar' $artifact.sha1 $artifact.size
            foreach ($type in @('mod', 'modpack', 'resourcepack', 'shader')) {
                $facets = [uri]::EscapeDataString(('[["project_type:{0}"]]' -f $type))
                $hits = Get-TestJson "https://api.modrinth.com/v2/search?limit=1&facets=$facets" "modrinth-$type-search"
                Assert-True ($hits.hits.Count -gt 0) "Modrinth $type search returns a resource"
            }
            $versions = Get-TestJson 'https://api.modrinth.com/v2/project/fabric-api/version?game_versions=%5B%221.20.1%22%5D&loaders=%5B%22fabric%22%5D' 'fabric-api-versions'
            $raw = $versions | Select-Object -First 1
            $parsed = [PCL.ResourceVersion]::FromPlatformJson([Newtonsoft.Json.Linq.JObject]::Parse(($raw | ConvertTo-Json -Depth 30)), [PCLCS.ResourceTypes]::Mod)
            Assert-True $parsed.DownloadAvailable 'Real launcher parser accepts Modrinth metadata'
            Assert-True ($parsed.DownloadUrls.Count -eq 1) 'Resource has one direct CDN URL and no retired mirror'
            Save-VerifiedFile $parsed.DownloadUrls[0] 'sample-fabric-api.jar' $parsed.Hash $parsed.Size
            $result.Online = 'PASS'
            $result.Assertions = $script:count
            $result['NetworkChecks'] = @($script:checks.ToArray())
            $result['SampleDirectory'] = $out
            $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'results.json') -Encoding UTF8
        } finally { $client.Dispose(); [PCL.ModBase]::PathTemp = $savedTemp }
    }
    $result | ConvertTo-Json -Depth 6
} finally { $keyField.SetValue($null, $savedKey) }
