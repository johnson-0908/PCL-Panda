[CmdletBinding()]
param([string]$BinaryDirectory)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Run with Windows PowerShell 5.1 and -STA.'
}
$root = Split-Path $PSScriptRoot -Parent
if (-not $BinaryDirectory) { $BinaryDirectory = Join-Path $root 'artifacts\builds\launch-dashboard' }
$script:count = 0
function Assert-True([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:count++
}
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
[void][Reflection.Assembly]::LoadFrom((Join-Path $BinaryDirectory 'PCLCS.dll'))
$exe = Join-Path $BinaryDirectory 'Plain Craft Launcher 2.exe'
$assembly = [Reflection.Assembly]::LoadFrom($exe)
$name = 'PCL2' + [char]0x590D + [char]0x6D3B + [char]0x7248
$oldName = [string][char]0x718A + [char]0x732B
$title = [PCLCS.LauncherBranding]::WindowTitle
Assert-True ([PCLCS.LauncherBranding]::DisplayName -eq $name) 'Requested local display name'
Assert-True ($title.StartsWith($name) -and $title.Length -gt $name.Length) 'Window title retains derivative-edition notice'
$info = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
Assert-True ($info.ProductName -eq $title) 'Compiled PE product name updated'
Assert-True ($info.FileDescription -eq $title) 'Compiled PE file description updated'
Assert-True ($assembly.GetName().Name -eq 'Plain Craft Launcher 2') 'Assembly identity preserved for pack URIs and custom XAML'
$flags = [Reflection.BindingFlags]'Public,NonPublic,Static'
$secret = $assembly.GetType('PCL.ModSecret',$true)
Assert-True ($secret.GetField('RegFolder',$flags).GetRawConstantValue() -eq 'PCLPanda') 'Existing account/config namespace preserved'
Assert-True ($secret.GetField('DefaultOAuthClientId',$flags).GetRawConstantValue() -eq 'd1652c9c-65d6-4007-86ff-cdfbe048e978') 'Existing OAuth application ID preserved'
$ua = [PCLCS.PandaDownloadPolicy]::GetUserAgent('test')
Assert-True ($ua.StartsWith('PCL2-Revived/') -and $ua -notmatch '[^\x20-\x7E]') 'HTTP product identifier remains ASCII'
Assert-True ($ua.Contains('https://github.com/johnson-0908/PCL-Panda')) 'Repository support URL unchanged'

[xml]$form = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\FormMain.xaml') -Raw -Encoding UTF8
$x = 'http://schemas.microsoft.com/winfx/2006/xaml'
Assert-True ($form.DocumentElement.GetAttribute('Title') -eq '{x:Static branding:LauncherBranding.WindowTitle}') 'Window reads shared brand constant'
$label = @($form.SelectNodes('//*[local-name()="TextBlock"]') | Where-Object { $_.GetAttribute('Name',$x) -eq 'LabDefaultTitleLogo' })[0]
Assert-True ($label.GetAttribute('Text') -eq '{x:Static branding:LauncherBranding.DisplayName}') 'Default titlebar reads shared brand constant'
Assert-True ($form.OuterXml -notmatch 'ShapeTitleLogo') 'Old vector lettering removed'
$formCode = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\FormMain.xaml.vb') -Raw -Encoding UTF8
Assert-True (([regex]::Matches($formCode,'LabDefaultTitleLogo.Visibility')).Count -eq 4) 'All default/custom/image/hidden title modes remain supported'
$appCode = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Application.xaml.vb') -Raw -Encoding UTF8
Assert-True ($appCode.Contains('FindWindow(Nothing, LauncherBranding.WindowTitle)')) 'Single-instance activation uses matching window title'
$license = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageSetup\PageSetupSystem.xaml') -Raw -Encoding UTF8
Assert-True ($license.Contains('LauncherBranding.LicenseNotice') -and $license.Contains('LTCat')) 'Edition notice updated; original author retained'

# Render only the stock TextBlock, never construct the real launcher window.
$markup = '<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" xmlns:branding="clr-namespace:PCLCS;assembly=PCLCS" Width="180" Height="48" Background="#1370F3" TextElement.FontFamily="Microsoft YaHei UI">' + $label.OuterXml + '</Grid>'
$view = [Windows.Markup.XamlReader]::Parse($markup)
$view.Measure([Windows.Size]::new(180,48))
$view.Arrange([Windows.Rect]::new(0,0,180,48))
$view.UpdateLayout()
$rendered = $view.FindName('LabDefaultTitleLogo')
Assert-True ($rendered.Text -eq $name) 'x:Static resolves to compiled brand at runtime'
Assert-True ($rendered.ActualWidth -gt 80 -and $rendered.ActualWidth -lt 150 -and $rendered.ActualHeight -lt 40) 'New title fits compact titlebar'
Assert-True ($null -eq [Windows.Application]::Current) 'No launcher application or window created'
foreach ($file in @('README.md','PROVENANCE.md','docs\AUTHENTICATION.md','Plain Craft Launcher 2\FormMain.xaml','Plain Craft Launcher 2\FormMain.xaml.vb','Plain Craft Launcher 2\Application.xaml.vb','Plain Craft Launcher 2\Modules\ModSecret.vb','Plain Craft Launcher 2\Pages\PageSetup\PageSetupSystem.xaml','Plain Craft Launcher 2\My Project\AssemblyInfo.vb','Plain Craft Launcher 2\Pages\PageLaunch\PageLaunchRight.xaml')) {
    $text = Get-Content -LiteralPath (Join-Path $root $file) -Raw -Encoding UTF8
    Assert-True (-not $text.Contains($oldName)) "No obsolete display name: $file"
}
[pscustomobject]@{Status='PASS';Assertions=$script:count;DisplayName=$name;LauncherStarted=$false;CloudApplicationRenamed=$false;StorageIdentityChanged=$false} | ConvertTo-Json
