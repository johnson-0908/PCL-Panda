[CmdletBinding()]
param(
    [string]$TargetDirectory,
    [string]$ExpectedVersion,
    [int]$ParentProcessId = 0,
    [long]$ParentStartTicks = 0,
    [switch]$NoRestart,
    [switch]$LibraryOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$AppFiles = @(
    'Plain Craft Launcher 2.exe','Plain Craft Launcher 2.exe.config','PCLCS.dll','MeloongCore.dll','MeloongCore.Wpf.dll',
    'MeloongCore.deps.json','Newtonsoft.Json.dll','Ookii.Dialogs.Wpf.dll','ThrottleDebounce.dll',
    'Microsoft.Win32.Registry.dll','System.Security.AccessControl.dll','System.Security.Principal.Windows.dll',
    'Apply-Update.ps1','LICENCE','MeloongCore-LICENSE.txt','README.md','PROVENANCE.md'
)
function Assert-SafePath([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse points are not allowed in update paths.' }
        }
        $current = [IO.Path]::GetDirectoryName($current.TrimEnd('\'))
    }
}
function Get-UpdateManifest([string]$Stage, [string]$Version) {
    Assert-SafePath $Stage
    $manifestPath = Join-Path $Stage 'update-manifest.json'
    Assert-SafePath $manifestPath
    if ((Get-Item -LiteralPath $manifestPath).Length -gt 65536) { throw 'Manifest too large.' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.repository -cne 'johnson-0908/PCL-Panda' -or
        $manifest.version -cne $Version -or $Version -cnotmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
        throw 'Invalid manifest identity/version.'
    }
    if (@($manifest.files).Count -ne $AppFiles.Count) { throw 'Incomplete manifest.' }
    $seen = @{}
    $total = 0L
    foreach ($entry in $manifest.files) {
        if ($AppFiles -cnotcontains $entry.name -or $seen.ContainsKey($entry.name) -or
            $entry.sha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or $entry.size -le 0 -or $entry.size -gt 268435456) {
            throw 'Invalid or duplicate manifest file.'
        }
        $seen[$entry.name] = $true
        $total += $entry.size
        if ($total -gt 268435456) { throw 'Expanded package too large.' }
        $path = Join-Path $Stage $entry.name
        Assert-SafePath $path
        $item = Get-Item -LiteralPath $path
        if ($item.PSIsContainer -or $item.Length -ne $entry.size -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $entry.sha256) { throw ('File validation failed: ' + $entry.name) }
    }
    return $manifest
}
function Save-UpdateState([string]$Path, [string]$State, [string]$Version, [string]$Message) {
    Assert-SafePath $Path
    @{state=$State;version=$Version;message=$Message;utc=[DateTime]::UtcNow.ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Restore-UpdateBackup([string]$Target, [string]$Backup, $Journal) {
    # Also callable manually after an interrupted process. Only exact application names are accepted.
    foreach ($entry in $Journal) {
        if (@($AppFiles + 'update-manifest.json') -cnotcontains $entry.name) { throw 'Unsafe rollback entry.' }
        $destination = Join-Path $Target $entry.name
        $source = Join-Path $Backup $entry.name
        Assert-SafePath $destination
        Assert-SafePath $source
        if ($entry.existed) {
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ine $entry.sha256) { throw 'Backup validation failed.' }
            # Skip unchanged files (including an unchanged file locked by another process).
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or
                (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ine $entry.sha256) {
                Copy-Item -LiteralPath $source -Destination $destination -Force
            }
        } elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
            Remove-Item -LiteralPath $destination -Force
        }
    }
}
function Install-LauncherUpdate([string]$Target, [string]$Version) {
    $target = [IO.Path]::GetFullPath($Target).TrimEnd('\')
    if ($target -eq [IO.Path]::GetPathRoot($target).TrimEnd('\')) { throw 'A drive root is not an installation directory.' }
    Assert-SafePath $target
    if (-not (Test-Path -LiteralPath (Join-Path $target 'Plain Craft Launcher 2.exe') -PathType Leaf)) { throw 'Launcher executable not found.' }
    $updates = Join-Path $target 'PCL\Updates'
    $stage = Join-Path $updates 'pending'
    $backup = Join-Path $updates 'backup'
    $state = Join-Path $updates 'result.json'
    Assert-SafePath $stage
    Assert-SafePath $backup
    Assert-SafePath $state
    if (Test-Path -LiteralPath $state) {
        $prior = Get-Content -LiteralPath $state -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($prior.state -in @('installing','rollback-failed')) { throw 'Interrupted update: restore the existing backup before retrying. See docs/UPDATES.md.' }
    }
    $manifest = Get-UpdateManifest $stage $Version
    $names = @($AppFiles + 'update-manifest.json')
    # Check existing destinations first. Do not rewrite the previous backup on basic validation failure.
    foreach ($name in $names) {
        $path = Join-Path $target $name
        Assert-SafePath $path
        if (Test-Path -LiteralPath $path) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Not a regular file: ' + $name) }
            $probe = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
            $probe.Dispose()
        }
    }
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $journal = @()
    foreach ($name in $names) {
        $original = Join-Path $target $name
        $saved = Join-Path $backup $name
        Assert-SafePath $saved
        $exists = Test-Path -LiteralPath $original -PathType Leaf
        $hash = $null
        if ($exists) {
            $hash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
            Copy-Item -LiteralPath $original -Destination $saved -Force
            if ((Get-FileHash -LiteralPath $saved -Algorithm SHA256).Hash -ine $hash) { throw 'Backup copy verification failed.' }
        } elseif (Test-Path -LiteralPath $saved -PathType Leaf) {
            Remove-Item -LiteralPath $saved -Force
        }
        $journal += [pscustomobject]@{name=$name;existed=$exists;sha256=$hash}
    }
    $journalPath = Join-Path $backup 'journal.json'
    Assert-SafePath $journalPath
    ConvertTo-Json -InputObject $journal -Depth 4 | Set-Content -LiteralPath $journalPath -Encoding UTF8
    Save-UpdateState $state 'installing' $Version 'Verified backup created; replacing only application files.'
    try {
        foreach ($name in $names) {
            Copy-Item -LiteralPath (Join-Path $stage $name) -Destination (Join-Path $target $name) -Force
        }
        $null = Get-UpdateManifest $target $Version
        Save-UpdateState $state 'installed' $Version 'Application files updated; game and settings directories were not modified.'
    } catch {
        $failure = $_.Exception.Message
        try {
            Restore-UpdateBackup $target $backup $journal
            Save-UpdateState $state 'rolled-back' $Version $failure
        } catch {
            Save-UpdateState $state 'rollback-failed' $Version ($failure + ' / Rollback: ' + $_.Exception.Message)
        }
        throw
    }
    # Keep only one previous application backup, not a new runnable bundle for every update.
    foreach ($name in $names) {
        $file = Join-Path $stage $name
        Assert-SafePath $file
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
    $zip = Join-Path $updates 'download.zip'
    Assert-SafePath $zip
    if (Test-Path -LiteralPath $zip -PathType Leaf) { Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }
}
if ($LibraryOnly) { return }

$exitCode = 0
try {
    if (-not $TargetDirectory -or -not $ExpectedVersion) { throw 'TargetDirectory and ExpectedVersion are required.' }
    $TargetDirectory = [IO.Path]::GetFullPath($TargetDirectory).TrimEnd('\')
    Assert-SafePath $TargetDirectory
    $exe = Join-Path $TargetDirectory 'Plain Craft Launcher 2.exe'
    if ($ParentProcessId -gt 0) {
        $parent = Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue
        if ($parent) {
            if ($parent.StartTime.ToUniversalTime().Ticks -ne $ParentStartTicks -or $parent.Path -ine $exe) { throw 'Parent process identity changed.' }
            if (-not $parent.WaitForExit(120000)) { throw 'Launcher did not exit; no files were changed.' }
        }
    }
    foreach ($process in @(Get-Process -Name 'Plain Craft Launcher 2' -ErrorAction SilentlyContinue)) {
        if ($process.Path -ieq $exe) { throw 'Another instance is using the application directory.' }
    }
    Install-LauncherUpdate $TargetDirectory $ExpectedVersion
} catch {
    $exitCode = 1
    # Do not include credentials or HTTP headers. Keep a single local diagnostic file.
    if ($TargetDirectory -and (Test-Path -LiteralPath (Join-Path $TargetDirectory 'PCL\Updates'))) {
        $log = Join-Path $TargetDirectory 'PCL\Updates\update-error.txt'
        Assert-SafePath $log
        $_.Exception.Message | Set-Content -LiteralPath $log -Encoding UTF8
    }
    Write-Error $_ -ErrorAction Continue
}
if (-not $NoRestart -and $TargetDirectory) {
    $result = Join-Path $TargetDirectory 'PCL\Updates\result.json'
    $unsafe = $false
    if (Test-Path -LiteralPath $result) {
        $status = Get-Content -LiteralPath $result -Raw -Encoding UTF8 | ConvertFrom-Json
        $unsafe = $status.state -in @('installing','rollback-failed')
    }
    if (-not $unsafe -and (Test-Path -LiteralPath $exe -PathType Leaf)) {
        # This is the user-requested interactive launcher, not a background helper.
        Start-Process -FilePath $exe -WorkingDirectory $TargetDirectory
    }
}
exit $exitCode
