[CmdletBinding()]
param([string]$BinaryDirectory, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $root 'artifacts\builds\launch-dashboard' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'artifacts\release' }
$BinaryDirectory = [IO.Path]::GetFullPath($BinaryDirectory)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
Add-Type -Path (Join-Path $BinaryDirectory 'Newtonsoft.Json.dll')
Add-Type -Path (Join-Path $BinaryDirectory 'PCLCS.dll')
$update = [PCLCS.LauncherUpdate]
$update::AssertSafePath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$version = $update::CurrentVersion
$package = Join-Path $OutputDirectory $update::AssetName
$manifest = @{schema=1;version=$version;repository=$update::Repository;files=@()}
$sources = @{}
foreach ($name in $update::AppFiles) {
    $file = Join-Path $BinaryDirectory $name
    if ($name -eq 'Apply-Update.ps1') { $file = Join-Path $PSScriptRoot $name }
    if ($name -in @('README.md','PROVENANCE.md','LICENCE')) { $file = Join-Path $root $name }
    if ($name -eq 'MeloongCore-LICENSE.txt') { $file = Join-Path $root 'MeloongCore\LICENSE.txt' }
    $update::AssertSafePath($file)
    $item = Get-Item -LiteralPath $file
    if ($item.PSIsContainer -or $item.Length -le 0) { throw ('Missing package file: ' + $name) }
    $sources[$name] = $file
    $manifest.files += @{name=$name;size=$item.Length;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
}
if ([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $BinaryDirectory $update::ExeName)).FileVersion -ne $update::FileVersion) {
    throw 'Executable and updater version differ. Build before packaging.'
}
# Write only the allowlisted files directly into a single ZIP; never archive the runtime directory.
$update::AssertSafePath($package)
$stream = [IO.File]::Open($package,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
    $archive = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        foreach ($name in $update::AppFiles) { $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$sources[$name],$name,[IO.Compression.CompressionLevel]::Optimal) }
        $entry = $archive.CreateEntry($update::ManifestName)
        $writer = [IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
        try { $writer.Write(($manifest | ConvertTo-Json -Depth 5)) } finally { $writer.Dispose() }
    } finally { $archive.Dispose() }
} finally { $stream.Dispose() }
$hash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
$hash + '  ' + $update::AssetName | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding ascii
[pscustomobject]@{Version=$version;Package=$package;SHA256=$hash;Files=$update::AppFiles.Count+1;RuntimeDataIncluded=$false} | ConvertTo-Json
