[CmdletBinding()]
param([string]$BinaryDirectory)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run with Windows PowerShell 5.1 (powershell.exe).' }
$root = Split-Path $PSScriptRoot -Parent
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $root 'artifacts\builds\launch-dashboard' }
[void][Reflection.Assembly]::LoadFrom((Join-Path $root 'Plain Craft Launcher 2\Resources\Newtonsoft.Json.dll'))
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $BinaryDirectory 'Plain Craft Launcher 2.exe'))
$script:count = 0
function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:count++
}
# Call the real compiled input validator and UUID builder. Do not invoke the
# login worker (which saves profile history), application startup, or Java.
$type = $assembly.GetType('PCL.ModLaunch+McLoginLegacy', $true)
$offline = [Activator]::CreateInstance($type)
$offline.UserName = 'PandaOfflineTest'
Assert-True ([PCL.ModLaunch]::McLoginAble($offline) -eq '') 'Accept an explicitly selected offline profile'
$uuid = [PCL.ModLaunch]::McLoginLegacyUuid($offline.UserName)
Assert-True ([PCLCS.PandaAuthenticationPolicy]::IsValidLaunchSession(0, 'Legacy', $uuid, $uuid, $offline.UserName)) 'Accept the actual upstream offline UUID/token structure'
Assert-True (-not [PCLCS.PandaAuthenticationPolicy]::IsValidLaunchSession(5, 'Legacy', $uuid, $uuid, $offline.UserName)) 'Offline profile is not Microsoft authentication'
$offline.UserName = ''
Assert-True ([PCL.ModLaunch]::McLoginAble($offline) -ne '') 'Reject an empty player name'
$offline.UserName = 'Bad"Name'
Assert-True ([PCL.ModLaunch]::McLoginAble($offline) -ne '') 'Retain the upstream quoted-name validation'
[pscustomobject]@{Status='PASS'; Assertions=$script:count; LauncherStarted=$false; GameStarted=$false; ProfileHistoryWritten=$false} | ConvertTo-Json
