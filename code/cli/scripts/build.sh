#!/usr/bin/env bash
# build.sh — Compile MACSS CLI and package locally (Linux)
#
# Usage: bash scripts/build.sh
# Run from code/cli/

set -euo pipefail

echo 'Building macss (Linux)...'

# 1. Compile
dart compile exe bin/main.dart -o bin/macss

# 2. Stage dist/
rm -rf dist
mkdir -p dist/bin dist/assets
cp bin/macss dist/bin/
cp -r assets/* dist/assets/

echo 'Build complete → dist/'
