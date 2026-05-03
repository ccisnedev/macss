# install.ps1 — Install MACSS CLI from GitHub Releases (Windows)
#
# Usage: iex (iwr https://raw.githubusercontent.com/ccisnedev/macss/main/code/cli/scripts/install.ps1).Content
# Or locally: .\scripts\install.ps1

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
New-Item -ItemType Directory -Force $binDir | Out-Null
Set-Content -Path "$binDir\ma.cmd" -Value "@echo off`r`nmacss %*"

# 4. Add to PATH
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$binDir", 'User')
    Write-Host "Added $binDir to user PATH."
}

# 5. Clean up
Remove-Item -Recurse -Force $tmpDir

Write-Host "MACSS CLI $tag installed. Open a new terminal and run: macss"
