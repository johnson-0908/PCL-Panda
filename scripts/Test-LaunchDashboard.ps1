[CmdletBinding()]
param([string]$BinaryDirectory, [string]$PreviewDirectory)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Run with Windows PowerShell 5.1: powershell.exe -NoProfile -STA -File scripts/Test-LaunchDashboard.ps1'
}
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
$flags = [Reflection.BindingFlags]'Public,NonPublic,Instance'
$type = $assembly.GetType('PCL.PageLaunchRight', $true)
$empty = [PCLCS.PandaLaunchDashboard]::Create($false, $null, $null, $null, $false, $false)
Assert-True ($empty.CanSelectVersion -and $empty.CanInstall -and -not $empty.CanManageVersion) 'Empty state has installation/selection but not instance settings'
Assert-True (-not $empty.CanOpenFolder -and $empty.Title.Length -gt 0) 'Unconfigured folder and nonblank empty state'
$selected = [PCLCS.PandaLaunchDashboard]::Create($false, '1.21.1 - Fabric', 'Minecraft 1.21.1 / Fabric 0.16', 'X:\SyntheticGame\.minecraft\', $false, $false)
Assert-True ($selected.Title -eq '1.21.1 - Fabric' -and $selected.Description -match 'Fabric') 'Shows actual selected instance metadata'
Assert-True ($selected.CanManageVersion -and $selected.CanOpenFolder -and -not $selected.HasError) 'Selected instance controls are enabled'
$loading = [PCLCS.PandaLaunchDashboard]::Create($true, $selected.Title, '', '', $false, $false)
Assert-True (-not $loading.CanInstall -and -not $loading.CanSelectVersion -and -not $loading.CanManageVersion -and $loading.Title -ne $selected.Title) 'Scanning does not show stale selection or allow mutation'
$launching = [PCLCS.PandaLaunchDashboard]::Create($false, $selected.Title, '', $selected.Folder, $false, $true)
Assert-True (-not $launching.CanInstall -and -not $launching.CanSelectVersion -and -not $launching.CanManageVersion -and $launching.CanOpenFolder) 'Launching guards selection/install without blocking folder access'
$invalid = [PCLCS.PandaLaunchDashboard]::Create($false, 'Broken instance', 'Invalid version JSON', $selected.Folder, $true, $false)
Assert-True ($invalid.HasError -and $invalid.CanManageVersion -and $invalid.Status -ne $selected.Status) 'Broken version is labelled and can be managed'
$blank = [PCLCS.PandaLaunchDashboard]::Create($false, ' ', ' ', ' ', $true, $false)
Assert-True (-not $blank.CanManageVersion -and -not $blank.HasError -and -not $blank.CanOpenFolder) 'Whitespace is not a usable instance or folder'
foreach ($property in [PCLCS.PandaLaunchDashboard].GetProperties()) {
    Assert-True ($null -eq $property.GetSetMethod()) "Immutable snapshot: $($property.Name)"
}

[xml]$source = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageLaunch\PageLaunchRight.xaml') -Raw -Encoding UTF8
$x = 'http://schemas.microsoft.com/winfx/2006/xaml'
$dashboard = @($source.SelectNodes('//*[local-name()="StackPanel"]') | Where-Object { $_.GetAttribute('Name',$x) -eq 'PanDashboard' })[0]
Assert-True ($dashboard.SelectNodes('./*[local-name()="Grid"][1]/*[local-name()="TextBlock"]').Count -eq 1) 'Header contains only the page title, without a right-hand brand label'
$buttons = @($dashboard.SelectNodes('.//*[local-name()="Button"]'))
Assert-True ($buttons.Count -eq 7) 'Seven real action buttons, no decorative links'
foreach ($button in $buttons) {
    $name = $button.GetAttribute('Name',$x)
    Assert-True ($type.GetMember($name, $flags).Length -gt 0) "Control compiled into the launcher: $name"
    Assert-True ($null -ne $type.GetMethod($button.GetAttribute('Click'), $flags)) "Action handler compiled: $name"
    # Only the native dashboard subtree is rendered below. Never load Application_Startup or page Loaded handlers.
    $button.RemoveAttribute('Click')
}
[xml]$left = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageLaunch\PageLaunchLeft.xaml') -Raw -Encoding UTF8
Assert-True ([int]$left.DocumentElement.GetAttribute('Width') -eq 280) 'Compact 280-DIP account column'
$login = @($left.SelectNodes('//*[local-name()="Grid"]') | Where-Object { $_.GetAttribute('Name',$x) -eq 'PanLogin' })[0]
Assert-True ($login.ParentNode.LocalName -eq 'ScrollViewer' -and $login.GetAttribute('VerticalAlignment') -eq 'Top') 'Login content stays top aligned and can scroll in short windows'
$code = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageLaunch\PageLaunchRight.xaml.vb') -Raw -Encoding UTF8
Assert-True ($code.Contains('PanDashboard.Visibility = Visibility.Visible') -and $code.Contains('PanDashboard.Visibility = Visibility.Collapsed')) 'Default dashboard coexists with custom homepage'
Assert-True ($code -notmatch '\{hint\}|\{cave\}') 'Retired builtin presets do not display unresolved placeholders'
Assert-True ($code.Contains('McLaunchLoader.OnStateChangedUi, AddressOf RefreshDashboard')) 'Launch-state changes refresh dashboard'
$leftCode = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Pages\PageLaunch\PageLaunchLeft.xaml.vb') -Raw -Encoding UTF8
Assert-True ($leftCode.Contains('FrmLaunchRight?.RefreshDashboard()')) 'Version/folder refresh also updates dashboard'

# Read actual source colors and instantiate only stock WPF controls with synthetic data.
[xml]$appSource = Get-Content -LiteralPath (Join-Path $root 'Plain Craft Launcher 2\Application.xaml') -Raw -Encoding UTF8
$brushes = @($appSource.SelectNodes('//*[local-name()="SolidColorBrush"]') | Where-Object { $_.GetAttribute('Key',$x) -like 'ColorBrush*' } | ForEach-Object { $_.OuterXml }) -join "`n"
$markup = '<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Padding="22,20,22,14" Background="#E1EDF9" TextElement.FontFamily="Microsoft YaHei UI" TextElement.FontSize="13"><Border.Resources>' + $brushes + '</Border.Resources>' + $dashboard.OuterXml + '</Border>'
$view = [Windows.Markup.XamlReader]::Parse($markup)
$long = [PCLCS.PandaLaunchDashboard]::Create($false, ('Very long instance name / ' * 12), ('Fabric / NeoForge / ' * 25), ('X:\SyntheticGame\' + ('LongFolder\' * 25)), $false, $false)
$cases = @(@('empty', $empty), @('selected', $selected), @('long', $long), @('loading', $loading), @('launching', $launching), @('invalid', $invalid))
$sizes = @()
if ($PreviewDirectory) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($PreviewDirectory)) }
foreach ($case in $cases) {
    foreach ($width in @(480, 560, 980)) {
        $view.DataContext = $case[1]
        $view.Width = $width
        $view.Measure([Windows.Size]::new($width, [double]::PositiveInfinity))
        $height = [Math]::Ceiling($view.DesiredSize.Height)
        $view.Arrange([Windows.Rect]::new(0,0,$width,$height))
        $view.UpdateLayout()
        Assert-True ($height -gt 300 -and $height -lt 520) "Compact vertical layout: $($case[0]) / $width"
        Assert-True ($view.FindName('LabDashboardTitle').Text -eq $case[1].Title) "Title binding updates: $($case[0]) / $width"
        Assert-True ($view.FindName('LabDashboardFolder').Text -eq $case[1].Folder) "Folder binding updates: $($case[0]) / $width"
        Assert-True ($view.FindName('BtnDashboardManage').IsEnabled -eq $case[1].CanManageVersion) "Enabled binding updates: $($case[0]) / $width"
        foreach ($button in $buttons) {
            $control = $view.FindName($button.GetAttribute('Name',$x))
            $position = $control.TranslatePoint([Windows.Point]::new(0,0), $view)
            Assert-True ($position.X -ge 0 -and ($position.X + $control.ActualWidth) -le ($width + 0.1) -and $control.ActualHeight -ge 27) "Action stays inside viewport: $($case[0]) / $width / $($control.Name)"
        }
        $sizes += [pscustomobject]@{State=$case[0]; Width=$width; Height=$height}
        if ($PreviewDirectory -and $width -eq 560 -and $case[0] -in @('empty','selected','long')) {
            $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap([int]($width*1.5), [int]($height*1.5), 144, 144, [Windows.Media.PixelFormats]::Pbgra32)
            $bitmap.Render($view)
            $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
            $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $file = [IO.File]::Create((Join-Path $PreviewDirectory ($case[0] + '.png')))
            try { $encoder.Save($file) } finally { $file.Dispose() }
        }
    }
}
Assert-True ($null -eq [Windows.Application]::Current) 'No application/window or startup handlers were run'
[pscustomobject]@{Status='PASS'; Assertions=$script:count; LauncherStarted=$false; AccountsOrGameDataTouched=$false; Layouts=$sizes; UiNavigation='MANUAL_TEST_PENDING'; Preview='Native dashboard subtree, synthetic data, offscreen WPF render'} | ConvertTo-Json -Depth 4
