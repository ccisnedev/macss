# build.ps1 — Compile MACSS CLI and package locally (Windows)
#
# Usage: .\scripts\build.ps1
# Run from code/cli/

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'Building macss (Windows)...'

# 1. Compile
dart compile exe bin/main.dart -o bin/macss.exe

# 2. Stage dist/
Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force dist/bin, dist/assets | Out-Null
Copy-Item bin/macss.exe dist/bin/
Copy-Item -Recurse assets/* dist/assets/

Write-Host 'Build complete → dist/'
