# install.ps1 — Install MACSS CLI from GitHub Releases (Windows)
#
#   irm https://macss.ccisne.dev/install.ps1 | iex
#
# This file is served from the site and exists nowhere else in the repository.
# It used to exist twice, and the copies diverged: the served one wrote a `ma`
# alias that invoked a bare `macss`, resolving through PATH. See
# code/cli/test/installer_layout_test.dart, which now refuses a second copy.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo       = 'ccisnedev/macss'
$asset      = 'macss-windows-x64.zip'
$installDir = "$env:LOCALAPPDATA\macss"
$binDir     = "$installDir\bin"
$tmpDir     = Join-Path $env:TEMP "macss_install_$(Get-Random)"

Write-Host "Installing MACSS CLI..."

# 1. Find latest release
$apiUrl  = "https://api.github.com/repos/$repo/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'macss-installer' }
$tag     = $release.tag_name
$dlUrl   = ($release.assets | Where-Object { $_.name -eq $asset }).browser_download_url

if (-not $dlUrl) {
    Write-Error "Asset '$asset' not found in release $tag"
    exit 1
}

Write-Host "Downloading $tag..."
New-Item -ItemType Directory -Force $tmpDir | Out-Null
$zipPath = Join-Path $tmpDir $asset
Invoke-WebRequest -Uri $dlUrl -OutFile $zipPath -UseBasicParsing

# 2. Extract
Write-Host "Extracting to $installDir..."
New-Item -ItemType Directory -Force $installDir | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

# 3. Create ma.cmd alias
#    %~dp0 is the directory of this .cmd, so `ma` always runs the macss.exe
#    sitting next to it. Invoking a bare `macss` would resolve through PATH and
#    could silently run a different installation.
New-Item -ItemType Directory -Force $binDir | Out-Null
Set-Content -Path "$binDir\ma.cmd" -Value @('@echo off', '"%~dp0macss.exe" %*')

# 4. Add to PATH
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$binDir", 'User')
    Write-Host "Added $binDir to user PATH."
}

# 5. Clean up
Remove-Item -Recurse -Force $tmpDir

Write-Host "MACSS CLI $tag installed. Open a new terminal and run: macss"
