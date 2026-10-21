[CmdletBinding()]
param([switch]$SourceOnly, [string]$BinaryDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run with Windows PowerShell 5.1 (powershell.exe).' }
$script:count = 0
function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:count++
}
Add-Type -Path (Join-Path $root 'PCLCS\Launch\PandaAuthenticationPolicy.cs')
$policy = [PCLCS.PandaAuthenticationPolicy]
foreach ($type in @(-1,1,2,3,4,6,99)) {
    Assert-True (-not $policy::IsAllowedLoginType($type)) "Reject login type $type"
}
Assert-True ($policy::IsAllowedLoginType(5)) 'Accept Microsoft login type'
Assert-True ($policy::IsAllowedLoginType(0)) 'Restore explicit offline login type'
$uuid = '123456781234423481231234567890ab'
Assert-True ($policy::IsValidLaunchSession(0,'Legacy',$uuid,$uuid,'OfflinePlayer')) 'Accept explicit offline session'
Assert-True ($policy::IsValidLaunchSession(5,'Microsoft','synthetic-test-token',$uuid,'TestPlayer')) 'Accept Microsoft launch session'
Assert-True (-not $policy::IsValidLaunchSession(5,'Legacy',$uuid,$uuid,'OfflinePlayer')) 'Never treat offline login as Microsoft authentication'
Assert-True (-not $policy::IsValidLaunchSession(0,'Microsoft','synthetic-test-token',$uuid,'TestPlayer')) 'Do not mix Microsoft sessions into offline mode'
Assert-True (-not $policy::IsValidLaunchSession(0,'Legacy','different-token',$uuid,'OfflinePlayer')) 'Reject inconsistent offline session'
Assert-True (-not $policy::IsValidLaunchSession(0,'Legacy',$uuid,$uuid,'')) 'Offline name remains required'
Assert-True (-not $policy::IsValidLaunchSession(0,'Legacy','invalid','invalid','OfflinePlayer')) 'Offline UUID remains validated'
Assert-True (-not $policy::IsValidLaunchSession(3,'Auth','synthetic-test-token',$uuid,'TestPlayer')) 'Do not enable unrelated login methods'
Assert-True ($policy::IsValidMicrosoftSession('Microsoft','synthetic-test-token',$uuid,'TestPlayer')) 'Accept valid session structure (not proof of ownership)'
foreach ($type in @('Legacy','Nide','Auth','', 'microsoft')) {
    Assert-True (-not $policy::IsValidMicrosoftSession($type,'synthetic-test-token',$uuid,'TestPlayer')) "Reject session type $type"
}
foreach ($bad in @('', ' ', $null)) {
    Assert-True (-not $policy::IsValidMicrosoftSession('Microsoft',$bad,$uuid,'TestPlayer')) 'Reject blank token'
    Assert-True (-not $policy::IsValidMicrosoftSession('Microsoft','synthetic-test-token',$uuid,$bad)) 'Reject blank profile name'
}
foreach ($bad in @('', 'not-a-uuid','00000000000000000000000000000000','12345678-1234-4234-8123-1234567890ab')) {
    Assert-True (-not $policy::IsValidMicrosoftSession('Microsoft','synthetic-test-token',$bad,'TestPlayer')) 'Reject invalid profile id'
}
Assert-True ($policy::ShouldSendCurseForgeKey('https://api.curseforge.com/v1/mods','synthetic-test-key')) 'Allow intended HTTPS API endpoint'
foreach ($url in @('http://api.curseforge.com/v1/mods','https://api.curseforge.com.attacker.test/v1/mods','https://example.test/api.curseforge.com','https://forgecdn.net/file','https://api.curseforge.com:8443/v1/mods','https://user@api.curseforge.com/v1/mods','https://api.curseforge.com@evil.test','not-a-url')) {
    Assert-True (-not $policy::ShouldSendCurseForgeKey($url,'synthetic-test-key')) "No key for $url"
}
Assert-True (-not $policy::ShouldSendCurseForgeKey('https://api.curseforge.com/v1/mods','')) 'No empty API key header'
$launch = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Modules\Minecraft\ModLaunch.vb') -Raw -Encoding UTF8
Assert-True ($launch.Contains('MsLoginStep5(CachedAccessToken)')) 'Cached ownership check present'
Assert-True ($launch.Contains('MsLoginStep6(CachedAccessToken)')) 'Cached Java profile check present'
Assert-True ($launch.Contains('MsLoginStep5(LoginResult.AccessToken)')) 'Fresh ownership check present'
Assert-True ($launch.Contains('MsLoginStep6(LoginResult.AccessToken)')) 'Fresh Java profile check present'
Assert-True (-not $launch.Contains('PCL\LatestLaunch.bat')) 'No independent launch script generation'
$run = [regex]::Match($launch, '(?s)Private Sub McLaunchRun\(.*?End Sub').Value
Assert-True ($run.IndexOf('IsValidLaunchSession') -ge 0 -and $run.IndexOf('IsValidLaunchSession') -lt $run.IndexOf('StartProcess(StartInfo)')) 'Mode-specific guard precedes Java start'
$loginUi = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageLaunch\PageLaunchLeft.xaml.vb') -Raw -Encoding UTF8
Assert-True (-not [regex]::IsMatch($loginUi, '(?m)^\s*LoginPageType = 1\s*$')) 'Do not force Microsoft-only UI'
Assert-True ($loginUi.Contains('RadioLoginType0.Visibility = Visibility.Visible')) 'Offline selector remains available'
$main = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\FormMain.xaml.vb') -Raw -Encoding UTF8
Assert-True (-not $main.Contains('If Not SuppressStartupPrompts AndAlso Settings.Get(Of Integer)("SystemEulaVersion")')) 'EULA is not suppressed'
Assert-True ($launch.Contains('https://meloong.com/afd/a/LTCat')) 'Author support prompt retained'
Assert-True ($launch.Contains('https://www.xbox.com/zh-cn/games/store/')) 'Purchase guidance retained'
$hash = $null
if (-not $SourceOnly) {
    if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $root 'artifacts\builds\launch-dashboard' }
    $exe = Join-Path $BinaryDirectory 'Plain Craft Launcher 2.exe'
    $base = Split-Path $exe
    $resolver = [ResolveEventHandler] {
        param($sender,$eventArgs)
        $path = Join-Path $base (([Reflection.AssemblyName]::new($eventArgs.Name)).Name + '.dll')
        if (Test-Path -LiteralPath $path) { return [Reflection.Assembly]::ReflectionOnlyLoadFrom($path) }
        return [Reflection.Assembly]::ReflectionOnlyLoad($eventArgs.Name)
    }
    [AppDomain]::CurrentDomain.add_ReflectionOnlyAssemblyResolve($resolver)
    try {
        $asm = [Reflection.Assembly]::ReflectionOnlyLoadFrom($exe)
        $secret = $asm.GetType('PCL.ModSecret',$true)
        $flags = [Reflection.BindingFlags]'Public,NonPublic,Static'
        Assert-True ($secret.GetField('RegFolder',$flags).GetRawConstantValue() -eq 'PCLPanda') 'Independent registry identity'
        Assert-True ($secret.GetField('DefaultOAuthClientId',$flags).GetRawConstantValue() -eq 'd1652c9c-65d6-4007-86ff-cdfbe048e978') 'Registered client id embedded'
        Assert-True ($secret.GetField('ClsBaseUrl',$flags).GetRawConstantValue() -eq '') 'No telemetry endpoint'
        Assert-True ($secret.GetField('RestrictMcDownload',$flags).GetRawConstantValue() -eq $false) 'Download feature available'
        $hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    } finally { [AppDomain]::CurrentDomain.remove_ReflectionOnlyAssemblyResolve($resolver) }
}
[pscustomobject]@{ Status='PASS'; Assertions=$script:count; ExecutableSha256=$hash; StartedLauncher=$false; LiveOAuthAndGameLaunch='NOT_TESTED'; MinecraftApproval='PENDING'; CurseForgeIntegration='DISABLED' } | ConvertTo-Json
