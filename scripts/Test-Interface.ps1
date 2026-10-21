[CmdletBinding()]
param([string]$BinaryDirectory)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run with Windows PowerShell 5.1 (powershell.exe).' }
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Run powershell.exe with -STA.' }
$root = Split-Path $PSScriptRoot -Parent
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $root 'artifacts\builds\launch-dashboard' }
$script:count = 0
function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:count++
}
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
[void][Reflection.Assembly]::LoadFrom((Join-Path $root 'Plain Craft Launcher 2\Resources\Newtonsoft.Json.dll'))
[void][Reflection.Assembly]::LoadFrom((Join-Path $BinaryDirectory 'PCLCS.dll'))
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $BinaryDirectory 'Plain Craft Launcher 2.exe'))
$static = [Reflection.BindingFlags]'Public,NonPublic,Static'
$instance = [Reflection.BindingFlags]'Public,NonPublic,Instance'
foreach ($name in @('PageOtherLeft','PageOtherHelp','PageOtherHelpDetail','PageOtherAbout','PageOtherTest','ModMain+HelpEntry')) {
    Assert-True ($null -eq $assembly.GetType("PCL.$name")) "Removed compiled type: $name"
}
foreach ($path in @('Pages\PageOther','Resources\Help.zip','Images\Heads')) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $root "Plain Craft Launcher 2\$path"))) "Removed source and assets: $path"
}
$form = $assembly.GetType('PCL.FormMain', $true)
Assert-True ($form.GetMember('BtnTitleSelect4', $instance).Length -eq 0) 'More navigation is absent, not collapsed'
$pageType = $assembly.GetType('PCL.FormMain+PageType', $true)
$pageCheck = $form.GetMethod('IsPageAvailable', $static)
foreach ($id in @(-1,4,9,99)) {
    Assert-True (-not $pageCheck.Invoke($null, @([Enum]::ToObject($pageType,$id)))) "Reject removed/unknown page route $id"
}
foreach ($id in @(0,1,2,3,5,6,7,8)) {
    Assert-True ($pageCheck.Invoke($null, @([Enum]::ToObject($pageType,$id)))) "Preserve page route $id"
}
$eventType = $assembly.GetType('PCL.CustomEvent+EventType', $true)
foreach ($id in @(3,9,10,11,12,18)) {
    Assert-True (-not [Enum]::IsDefined($eventType, $id)) "Removed help/toolbox event $id"
}
foreach ($id in @(0,1,2,4,5,6,7,8,13,14,15,16,17,19,20,21,22,23,24)) {
    Assert-True ([Enum]::IsDefined($eventType, $id)) "Preserve custom-event numeric identity $id"
}
$main = $assembly.GetType('PCL.ModMain', $true)
foreach ($method in @('HelpLoad','HelpTryExtract','Feedback')) {
    Assert-True ($null -eq $main.GetMethod($method,$static)) "Removed implementation: $method"
}
foreach ($name in $assembly.GetManifestResourceNames()) {
    if (-not $name.EndsWith('.resources')) { continue }
    $reader = New-Object Resources.ResourceReader($assembly.GetManifestResourceStream($name))
    try {
        $keys = @($reader.GetEnumerator() | ForEach-Object { [string]$_.Key })
        Assert-True (-not ($keys -match '(?i)(pageother/|images/heads/|^Help$)')) "No removed BAML, artwork or help payload in $name"
    } finally { $reader.Dispose() }
}
$entries = [PCL.Settings]::Entries
Assert-True (-not ($entries.Keys -match '^(UiHiddenOther|UiHiddenPageOther|SystemHelpVersion|LaunchArgumentRam|VersionRamOptimize|UiLauncherThemeHide)')) 'Obsolete settings are removed'
[xml]$ui = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageSetup\PageSetupUI.xaml') -Raw -Encoding UTF8
$ns = 'http://schemas.microsoft.com/winfx/2006/xaml'
$grid = $ui.SelectNodes('//*[local-name()="Grid"]') | Where-Object { $_.GetAttribute('Name',$ns) -eq 'PanLauncherTheme' }
$radios = @($grid.SelectNodes('*[local-name()="MyRadioBox"]'))
Assert-True ($radios.Count -eq 15) 'All 14 palettes and the custom option are present'
foreach ($radio in $radios) {
    Assert-True ($radio.GetAttribute('IsEnabled') -ne 'False' -and $radio.GetAttribute('Opacity') -ne '0') "Theme control is enabled: $($radio.GetAttribute('Name',$ns))"
}
$setupType = $assembly.GetType('PCL.PageSetupUI', $true)
foreach ($name in @('PanLauncherHide','RadioLauncherTheme5Gray','LabLauncherTheme5Unlock','LabLauncherTheme8Copy','LabLauncherTheme9Copy','LabLauncherTheme11Click')) {
    Assert-True ($setupType.GetMember($name,$instance).Length -eq 0) "No theme overlay in binary: $name"
}
# Empty WPF resource owner only: no launcher window or Application_Startup.
# Settings below use a synthetic in-memory cache, not Settings.Set or Save.
$app = New-Object Windows.Application
$secret = $assembly.GetType('PCL.ModSecret', $true)
$refresh = $secret.GetMethod('ThemeRefresh',$static)
$colors = @()
try {
    foreach ($id in 0..13) {
        $palette = [PCLCS.PandaThemePalette]::Resolve($id)
        Assert-True ($palette.Id -eq $id -and $palette.Hue -ge 0 -and $palette.Hue -lt 360 -and $palette.Saturation -ge 0 -and $palette.Saturation -le 100) "Valid local palette $id"
        [void]$refresh.Invoke($null, @($id))
        Assert-True ($secret.GetField('ThemeNow',$static).GetValue($null) -eq $id) "Actual launcher selects theme $id"
        Assert-True ($null -ne $app.Resources['ColorBrush3']) "Actual WPF color resources refresh for $id"
        $colors += $app.Resources['ColorBrush3'].Color.ToString()
    }
    Assert-True (@($colors | Sort-Object -Unique).Count -eq 14) 'Preset selection changes actual accent colors'
    foreach ($id in @(-1,15,[int]::MaxValue)) {
        Assert-True ([PCLCS.PandaThemePalette]::Resolve($id).Id -eq 0) 'Invalid palette falls back to blue'
    }
    $low = [PCLCS.PandaThemePalette]::Resolve(14,-1,-1,-1,-1)
    $high = [PCLCS.PandaThemePalette]::Resolve(14,999,999,999,999)
    Assert-True ($low.Hue -eq 0 -and $low.Saturation -eq 0 -and $low.Delta -eq -90 -and $low.LightAdjustment -eq -20) 'Clamp lower custom bounds'
    Assert-True ($high.Hue -eq 0 -and $high.Saturation -eq 100 -and $high.Delta -eq 90 -and $high.LightAdjustment -eq 20) 'Clamp upper custom bounds'
    $values = @{UiLauncherHue=271; UiLauncherSat=64; UiLauncherDelta=120; UiLauncherLight=24}
    foreach ($key in $values.Keys) { $entries[$key].ValueCache[''] = $values[$key] }
    [void]$refresh.Invoke($null, @(14))
    Assert-True ($secret.GetField('ColorHue',$static).GetValue($null) -eq 271) 'Custom hue reaches the real renderer'
    Assert-True ($secret.GetField('ColorSat',$static).GetValue($null) -eq 64) 'Custom saturation reaches the real renderer'
    Assert-True ($secret.GetField('ColorLightAdjust',$static).GetValue($null) -eq 4) 'Custom lightness reaches the real renderer'
    $before = $app.Resources['ColorBrush3'].Color.ToString()
    $entries['UiLauncherHue'].ValueCache[''] = 90
    $entries['UiLauncherHue'].OnChanged.Invoke([object]90)
    Assert-True ($secret.GetField('ColorHue',$static).GetValue($null) -eq 90 -and $app.Resources['ColorBrush3'].Color.ToString() -ne $before) 'Custom slider callback updates the theme immediately'
    $secret.GetField('ThemeNow',$static).SetValue($null,-1)
    [void]$refresh.Invoke($null, @(14))
    Assert-True ($secret.GetField('ColorHue',$static).GetValue($null) -eq 90) 'Reselecting custom retains cached parameters'
    Assert-True ($app.Windows.Count -eq 0) 'No launcher window was opened'
} finally { $app.Shutdown() }
[pscustomobject]@{Status='PASS'; Assertions=$script:count; LauncherStarted=$false; SettingsWritten=$false; AccountsOrGameDataTouched=$false; VisualInteraction='MANUAL_TEST_PENDING'} | ConvertTo-Json
