[CmdletBinding()]
param([string]$BinaryDirectory, [switch]$Online)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $root 'artifacts\builds\launch-dashboard' }
$script:count = 0
function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw ('FAIL: ' + $Name) }
    $script:count++
}
function Assert-Rejected([scriptblock]$Action, [string]$Name) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert-True $rejected $Name
}
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
Add-Type -Path (Join-Path $BinaryDirectory 'Newtonsoft.Json.dll')
Add-Type -Path (Join-Path $BinaryDirectory 'PCLCS.dll')
$u = [PCLCS.LauncherUpdate]
. (Join-Path $PSScriptRoot 'Apply-Update.ps1') -LibraryOnly
Assert-True (($AppFiles -join '|') -ceq ($u::AppFiles -join '|')) 'Installer and client file allowlists match exactly'
Assert-True ($u::ApiUrl -eq 'https://api.github.com/repos/johnson-0908/PCL-Panda/releases/latest') 'Only our GitHub release channel'
Assert-True ($u::IsNewer('1.10.0','1.9.0')) 'Numeric version comparison, not lexical'
Assert-True (-not $u::IsNewer('1.0.0','1.0.0')) 'Same version never updates'
Assert-True (-not $u::IsNewer('1.0.0','2.0.0')) 'Never downgrades automatically'
foreach ($bad in @('', 'v1.0','01.0.0','1.0.0-beta','1.0.0.0','1.2.-1','999999999999.0.0','1.0.0/../bad')) {
    Assert-Rejected { $u::ParseVersion($bad) } ('Reject version ' + $bad)
}
foreach ($url in @('http://github.com','https://github.com:8443','https://github.com.evil.test','https://user@github.com','https://github.com/#fragment','https://example.test')) {
    Assert-True (-not $u::IsAllowedNetworkUri([uri]$url)) ('Reject redirect ' + $url)
}
foreach ($url in @('https://api.github.com','https://github.com','https://release-assets.githubusercontent.com/a','https://objects.githubusercontent.com/a')) {
    Assert-True ($u::IsAllowedNetworkUri([uri]$url)) 'Expected HTTPS download host'
}
function New-ReleaseJson {
    return @{
        draft=$false;prerelease=$false;tag_name='v1.1.0';html_url=$u::ReleasesUrl+'/tag/v1.1.0';body='Synthetic release'
        assets=@(@{name=$u::AssetName;state='uploaded';size=1234;digest='sha256:'+('a'*64);browser_download_url=$u::ReleasesUrl+'/download/v1.1.0/'+$u::AssetName})
    }
}
$release = $u::ParseRelease(((New-ReleaseJson) | ConvertTo-Json -Depth 5))
Assert-True ($release.Version -eq '1.1.0' -and $release.Size -eq 1234) 'Valid release metadata'
foreach ($flag in @('draft','prerelease')) {
    $json = New-ReleaseJson; $json[$flag]=$true
    Assert-True ($null -eq $u::ParseRelease(($json | ConvertTo-Json -Depth 5))) ('Ignore ' + $flag)
}
foreach ($field in @('digest','browser_download_url','state','name')) {
    $json = New-ReleaseJson; $json.assets[0][$field]='invalid'
    Assert-Rejected { $u::ParseRelease(($json | ConvertTo-Json -Depth 5)) } ('Reject missing/invalid asset ' + $field)
}
foreach ($size in @(0, -1, 134217729)) {
    $json = New-ReleaseJson; $json.assets[0].size=$size
    Assert-Rejected { $u::ParseRelease(($json | ConvertTo-Json -Depth 5)) } 'Reject asset size boundary'
}
$json = New-ReleaseJson; $json.html_url='https://github.com/other/project/releases/tag/v1.1.0'
Assert-Rejected { $u::ParseRelease(($json | ConvertTo-Json -Depth 5)) } 'Reject different repository'
$json = New-ReleaseJson; $json.assets += $json.assets[0]
Assert-Rejected { $u::ParseRelease(($json | ConvertTo-Json -Depth 5)) } 'Reject ambiguous asset'

$fixtures = Join-Path $root 'artifacts\update-tests'
$u::AssertSafePath($fixtures)
New-Item -ItemType Directory -Path $fixtures -Force | Out-Null
$target = Join-Path $fixtures 'synthetic-install'
New-Item -ItemType Directory -Path $target -Force | Out-Null
$junction=Join-Path $fixtures 'junction-probe'
if (-not (Test-Path -LiteralPath $junction)) { New-Item -ItemType Junction -Path $junction -Target $target | Out-Null }
Assert-Rejected { $u::AssertSafePath((Join-Path $junction 'PCL\Updates')) } 'Client rejects directory junction ancestor'
Assert-Rejected { Assert-SafePath (Join-Path $junction 'PCL\Updates') } 'Installer rejects directory junction ancestor'
# No real EXE, accounts or game files are used or launched by this test.
foreach ($name in @($AppFiles + 'update-manifest.json')) { [IO.File]::WriteAllText((Join-Path $target $name), ('old:'+$name)) }
foreach ($name in @('PCL\config.json','.minecraft\saves\synthetic.dat','custom-home.xaml')) {
    $p=Join-Path $target $name
    New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($p,'private-synthetic-sentinel')
}
function New-TestZip([string]$Extra='', [bool]$BadHash=$false) {
    $zip = Join-Path $fixtures 'synthetic.zip'
    $manifest=@{schema=1;version='1.1.0';repository=$u::Repository;files=@()}
    $f=[IO.File]::Open($zip,[IO.FileMode]::Create)
    $archive=[IO.Compression.ZipArchive]::new($f,[IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $AppFiles) {
            $bytes=[Text.Encoding]::UTF8.GetBytes('new:'+$name)
            $hash=[Security.Cryptography.SHA256]::Create()
            try { $sha=[BitConverter]::ToString($hash.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() } finally { $hash.Dispose() }
            if ($BadHash -and $name -eq 'PCLCS.dll') { $sha='0'*64 }
            $manifest.files += @{name=$name;size=$bytes.Length;sha256=$sha}
            $s=$archive.CreateEntry($name).Open(); try { $s.Write($bytes,0,$bytes.Length) } finally { $s.Dispose() }
        }
        if ($Extra) { $s=$archive.CreateEntry($Extra).Open(); $s.Dispose() }
        $w=[IO.StreamWriter]::new($archive.CreateEntry('update-manifest.json').Open(),[Text.UTF8Encoding]::new($false))
        try { $w.Write(($manifest | ConvertTo-Json -Depth 5)) } finally { $w.Dispose() }
    } finally { $archive.Dispose(); $f.Dispose() }
    return $zip
}
function Prepare-TestZip([string]$Zip) { $u::PreparePackage($Zip,$target,'1.1.0',(Get-FileHash $Zip -Algorithm SHA256).Hash,(Get-Item $Zip).Length) }
$zip=New-TestZip
Assert-Rejected { $u::PreparePackage($zip,$target,'1.1.0',('0'*64),(Get-Item $zip).Length) } 'Reject package hash mismatch'
Assert-Rejected { $u::PreparePackage($zip,$target,'1.1.0',(Get-FileHash $zip).Hash,1) } 'Reject package size mismatch'
Assert-Rejected { $u::PreparePackage($zip,$target,'1.2.0',(Get-FileHash $zip).Hash,(Get-Item $zip).Length) } 'Reject manifest release version mismatch'
foreach ($extra in @('../escape.txt','PCL/config.json','.minecraft/saves/x','PCLCS.dll','pclcs.dll','C:\escape.txt')) {
    $zip=New-TestZip $extra
    Assert-Rejected { Prepare-TestZip $zip } ('Reject ZIP path/extra/duplicate ' + $extra)
}
$zip=New-TestZip '' $true
Assert-Rejected { Prepare-TestZip $zip } 'Reject per-file hash mismatch'
$zip=New-TestZip
$stage=Prepare-TestZip $zip
Assert-True ((Get-Content -LiteralPath (Join-Path $target $u::ExeName) -Raw) -eq 'old:Plain Craft Launcher 2.exe') 'Preparing update does not touch installed files'
# Locked-file failure must happen before replacing anything.
$locked=[IO.File]::Open((Join-Path $target 'PCLCS.dll'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { Assert-Rejected { Install-LauncherUpdate $target '1.1.0' } 'Locked application is not overwritten' } finally { $locked.Dispose() }
Assert-True ((Get-Content -LiteralPath (Join-Path $target $u::ExeName) -Raw) -eq 'old:Plain Craft Launcher 2.exe') 'Preflight failure leaves EXE unchanged'
# A failed helper preflight must leave a visible result for the next launcher startup.
$errorPreference=$ErrorActionPreference
$ErrorActionPreference='Continue'
try {
    $failureOutput=& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Apply-Update.ps1') -TargetDirectory $target -ExpectedVersion '9.0.0' -NoRestart 2>&1
    $failureCode=$LASTEXITCODE
} finally { $ErrorActionPreference=$errorPreference }
Assert-True ($failureCode -ne 0) 'Helper preflight failure returns nonzero'
$failedResult=Get-Content -LiteralPath (Join-Path $target 'PCL\Updates\result.json') -Raw | ConvertFrom-Json
Assert-True ($failedResult.state -eq 'failed') 'Helper preflight error is visible on next startup'
Assert-True ((Get-Content -LiteralPath (Join-Path $target $u::ExeName) -Raw) -eq 'old:Plain Craft Launcher 2.exe') 'Helper failure preserves installed EXE'
# Inject a copy failure AFTER the first two application files changed; exercise the actual rollback path.
$script:copyFailed=$false
function Copy-Item([string]$LiteralPath,[string]$Destination,[switch]$Force) {
    if (-not $script:copyFailed -and $LiteralPath -eq (Join-Path $stage 'PCLCS.dll')) {
        $script:copyFailed=$true
        throw 'Synthetic mid-install disk failure'
    }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
}
try { Assert-Rejected { Install-LauncherUpdate $target '1.1.0' } 'Mid-install failure reported' } finally { Remove-Item -LiteralPath Function:\Copy-Item }
Assert-True $script:copyFailed 'Fault occurred during replacement, not preflight'
$result=Get-Content -LiteralPath (Join-Path $target 'PCL\Updates\result.json') -Raw | ConvertFrom-Json
Assert-True ($result.state -eq 'rolled-back') 'Partial installation rolled back'
foreach ($name in @($AppFiles + 'update-manifest.json')) {
    Assert-True ((Get-Content -LiteralPath (Join-Path $target $name) -Raw) -eq ('old:'+$name)) ('Original restored: '+$name)
}
# Run the actual out-of-process helper without restart, on the synthetic installation only.
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Apply-Update.ps1') -TargetDirectory $target -ExpectedVersion '1.1.0' -NoRestart
Assert-True ($LASTEXITCODE -eq 0) 'Standalone installer process succeeds'
$result=Get-Content -LiteralPath (Join-Path $target 'PCL\Updates\result.json') -Raw | ConvertFrom-Json
Assert-True ($result.state -eq 'installed') 'Successful installation recorded'
foreach ($name in $AppFiles) {
    Assert-True ((Get-Content -LiteralPath (Join-Path $target $name) -Raw) -eq ('new:'+$name)) ('Installed allowlisted file: '+$name)
    Assert-True ((Get-Content -LiteralPath (Join-Path $target ('PCL\Updates\backup\'+$name)) -Raw) -eq ('old:'+$name)) 'One previous version backup'
}
foreach ($name in @('PCL\config.json','.minecraft\saves\synthetic.dat','custom-home.xaml')) {
    Assert-True ((Get-Content -LiteralPath (Join-Path $target $name) -Raw) -eq 'private-synthetic-sentinel') ('Protected runtime file unchanged: '+$name)
}
Assert-True (@(Get-ChildItem -LiteralPath $stage -File).Count -eq 0) 'Staged payload removed after success'
$flow=Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Modules\ModLauncherUpdate.vb') -Raw -Encoding UTF8
Assert-True ($flow.Contains('If Not Manual Then') -and $flow.Contains('RevivedUpdateAutoCheck')) 'Startup auto-check can be disabled'
Assert-True ($flow.Contains('McInstanceLock.IsAnyLocked') -and $flow.Contains('ConfigUtils.SaveAll()')) 'Installation waits for tasks and saves settings'
if ($Online) {
    $latest=$u::CheckLatest()
    if ($latest) { Assert-True ($latest.PageUrl.StartsWith($u::ReleasesUrl+'/tag/')) 'Live release belongs to own repository' }
    else { Assert-True $true 'No release yet is a valid live response' }
}
[pscustomobject]@{Status='PASS';Assertions=$script:count;Online=[bool]$Online;RealLauncherStarted=$false;SyntheticUpdateAndRollback=$true} | ConvertTo-Json
