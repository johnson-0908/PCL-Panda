[CmdletBinding()]
param([string]$CacheRoot, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo 'artifacts\builds\launch-dashboard' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$targetExe = Join-Path $OutputDirectory 'Plain Craft Launcher 2.exe'
# Keep a single output directory. Never create another build to work around a running launcher.
foreach ($process in @(Get-Process -Name 'Plain Craft Launcher 2' -ErrorAction SilentlyContinue)) {
    if ($process.Path -and $process.Path.Equals($targetExe, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Close the launcher in '$OutputDirectory' before rebuilding. No extra build directory was created."
    }
}
if (-not $CacheRoot) { $CacheRoot = Join-Path $repo '.cache' }
$CacheRoot = [IO.Path]::GetFullPath($CacheRoot)
$dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere) -or -not (Test-Path -LiteralPath $dotnet)) {
    throw 'Install Visual Studio 2022 .NET desktop build tools, .NET Framework 4.8 targeting pack, and .NET SDK 9.'
}
$msbuild = @(& $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild\Current\Bin\MSBuild.exe') | Select-Object -First 1
if (-not $msbuild) { throw 'Visual Studio MSBuild was not found.' }
$env:DOTNET_ROOT = Split-Path $dotnet
$env:DOTNET_ROOT_X64 = $env:DOTNET_ROOT
$env:DOTNET_CLI_HOME = Join-Path $CacheRoot 'dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:NUGET_PACKAGES = Join-Path $CacheRoot 'nuget\packages'
$env:NUGET_HTTP_CACHE_PATH = Join-Path $CacheRoot 'nuget\http'
$env:TEMP = Join-Path $CacheRoot 'panda-build-temp'
$env:TMP = $env:TEMP
$logDir = Join-Path $repo 'artifacts\logs'
New-Item -ItemType Directory -Path $env:TEMP,$logDir -Force | Out-Null
$outputArgs = @('-p:OutDir=' + $OutputDirectory.TrimEnd('\') + '\')
Push-Location $repo
try {
    & $dotnet restore 'PCLCS\PCLCS.csproj' --verbosity minimal 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'restore.log')
    if ($LASTEXITCODE -ne 0) { throw "Restore failed: $LASTEXITCODE" }
    & $msbuild 'Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj' '-p:Configuration=Release' '-p:Platform=AnyCPU' '-p:DebugType=None' '-p:DebugSymbols=false' "-p:PathMap=$repo=/_/pcl-panda" @outputArgs '-verbosity:minimal' '-nologo' 2>&1 | Tee-Object -FilePath (Join-Path $logDir 'build.log')
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
} finally { Pop-Location }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Apply-Update.ps1') -Destination (Join-Path $OutputDirectory 'Apply-Update.ps1') -Force
Write-Output "Build completed: $targetExe"
Write-Output 'Run scripts/Test-PublicBuild.ps1 with Windows PowerShell next.'
