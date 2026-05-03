# dev-install.ps1 — Build from source and install MACSS CLI locally (Windows)
#
# Usage: .\scripts\dev-install.ps1
# Run from code/cli/

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installDir = "$env:LOCALAPPDATA\macss"
$binDir     = "$installDir\bin"

Write-Host "Building macss CLI..."
dart pub get
dart compile exe bin/main.dart -o bin/macss.exe

Write-Host "Installing to $installDir..."

# Create directories
New-Item -ItemType Directory -Force "$binDir" | Out-Null
New-Item -ItemType Directory -Force "$installDir\assets" | Out-Null

# Copy binary and assets
Copy-Item -Force bin/macss.exe "$binDir\macss.exe"
if (Test-Path assets) {
    Copy-Item -Recurse -Force assets/* "$installDir\assets\"
}

# Create alias ma.cmd
$maCmd = "$binDir\ma.cmd"
Set-Content -Path $maCmd -Value "@echo off`r`nmacss %*"

# Add to PATH if needed
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable('PATH', "$userPath;$binDir", 'User')
    Write-Host "Added $binDir to user PATH."
}

Write-Host "Done. Open a new terminal and run: macss"
