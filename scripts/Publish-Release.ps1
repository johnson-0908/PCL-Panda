[CmdletBinding()]
param([string]$CacheRoot, [switch]$Publish)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
if (git status --porcelain) { throw 'Commit reviewed source first. This script never commits or pushes your working tree.' }
& python scripts/audit_public.py --staged
if ($LASTEXITCODE -ne 0) { throw 'Public-source audit failed.' }
$buildArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'Build.ps1'))
if ($CacheRoot) { $buildArgs += @('-CacheRoot',$CacheRoot) }
& powershell.exe @buildArgs
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
foreach ($test in @('Test-PublicBuild','Test-Downloads','Test-OfflineLogin','Test-Interface','Test-LaunchDashboard','Test-Branding','Test-Updates')) {
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot ($test+'.ps1'))
    if ($LASTEXITCODE -ne 0) { throw ('Test failed: '+$test) }
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Package-Release.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed.' }
& python scripts/audit_release.py
if ($LASTEXITCODE -ne 0) { throw 'Release package audit failed.' }
if (-not $Publish) { Write-Output 'Validated locally only. Pass -Publish to publish reviewed source as a GitHub Release.'; return }
$repo='johnson-0908/PCL-Panda'
$head=(git rev-parse HEAD).Trim()
$remote=(gh api "repos/$repo/commits/main" --jq '.sha')
if ($LASTEXITCODE -ne 0 -or $remote -ne $head) { throw 'Push the reviewed commit to main before publishing.' }
Add-Type -Path (Join-Path $root 'artifacts\builds\launch-dashboard\PCLCS.dll')
$version=[PCLCS.LauncherUpdate]::CurrentVersion
$tag='v'+$version
$package=Join-Path $root 'artifacts\release\PCL2-Revived-win-x64.zip'
$checksums=Join-Path $root 'artifacts\release\SHA256SUMS.txt'
$hash=(Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
# A draft is invisible to ordinary clients; never replace an existing published release.
$existing=gh release list --repo $repo --limit 1000 --json tagName | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect existing releases.' }
if (@($existing | Where-Object { $_.tagName -eq $tag }).Count -gt 0) { throw 'Release already exists. Inspect it manually; published assets must not be overwritten.' }
$existingTag=git ls-remote --tags origin ('refs/tags/'+$tag)
if ($LASTEXITCODE -ne 0 -or $existingTag) { throw 'Could not verify that the version tag is new.' }
gh release create $tag $package $checksums --repo $repo --target $head --draft --title ([PCLCS.LauncherBranding]::DisplayName + " " + $version) --notes-file docs/RELEASE-NOTES.md
if ($LASTEXITCODE -ne 0) { throw 'Draft creation/upload failed. Inspect the existing draft before retrying.' }
# An unpublished draft may not yet have a resolvable Git tag. Look up its release ID instead.
$drafts=gh api "repos/$repo/releases?per_page=100" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not list drafts.' }
$matching=@($drafts | Where-Object { $_.tag_name -eq $tag -and $_.draft })
if ($matching.Count -ne 1) { throw 'Could not identify the newly created draft.' }
$release=gh api ("repos/$repo/releases/"+$matching[0].id) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not verify draft by ID.' }
$asset=@($release.assets | Where-Object { $_.name -eq 'PCL2-Revived-win-x64.zip' })
if ($asset.Count -ne 1 -or $asset[0].digest -ne ('sha256:'+$hash) -or $asset[0].size -ne (Get-Item -LiteralPath $package).Length) {
    throw 'Uploaded package digest/size mismatch. Draft was not published.'
}
$sums=@($release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' })
if ($sums.Count -ne 1 -or $sums[0].digest -ne ('sha256:'+(Get-FileHash -LiteralPath $checksums -Algorithm SHA256).Hash.ToLowerInvariant())) {
    throw 'Uploaded checksum file mismatch. Draft was not published.'
}
gh release edit $tag --repo $repo --tag $tag --target $head --draft=false --prerelease=false --latest --title ([PCLCS.LauncherBranding]::DisplayName + ' ' + $version) --notes-file docs/RELEASE-NOTES.md
if ($LASTEXITCODE -ne 0) { throw 'Draft verified, but publishing failed. Inspect the existing release.' }
gh release view $tag --repo $repo --json url,isDraft,tagName
if ($LASTEXITCODE -ne 0) { throw 'Release published but final readback failed.' }
$publishedHead=gh api "repos/$repo/commits/$tag" --jq '.sha'
if ($LASTEXITCODE -ne 0 -or $publishedHead -ne $head) { throw 'Published tag does not resolve to the reviewed source commit.' }
