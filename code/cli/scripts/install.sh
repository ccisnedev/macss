#!/usr/bin/env bash
# install.sh — Install MACSS CLI from GitHub Releases (Linux)
#
# Usage: curl -fsSL https://raw.githubusercontent.com/ccisnedev/macss/main/code/cli/scripts/install.sh | bash
# Or locally: bash scripts/install.sh

set -euo pipefail

REPO="ccisnedev/macss"
ASSET="macss-linux-x64.tar.gz"
INSTALL_DIR="$HOME/.macss"
BIN_DIR="$INSTALL_DIR/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Installing MACSS CLI..."

# 1. Find latest release
API_URL="https://api.github.com/repos/$REPO/releases/latest"
RELEASE=$(curl -fsSL -H "User-Agent: macss-installer" "$API_URL")
TAG=$(echo "$RELEASE" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
DL_URL=$(echo "$RELEASE" | grep "browser_download_url" | grep "$ASSET" | sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

if [[ -z "$DL_URL" ]]; then
    echo "Error: asset '$ASSET' not found in release $TAG" >&2
    exit 1
fi

echo "Downloading $TAG..."
curl -fsSL -o "$TMP_DIR/$ASSET" "$DL_URL"

# 2. Extract
echo "Extracting to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
tar xzf "$TMP_DIR/$ASSET" -C "$INSTALL_DIR"

# 3. Mark executable and create alias
chmod +x "$BIN_DIR/macss"
ln -sf "$BIN_DIR/macss" "$BIN_DIR/ma"

# 4. Add to PATH in shell profile
for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [[ -f "$profile" ]] && ! grep -q 'macss/bin' "$profile"; then
        echo '' >> "$profile"
        echo '# MACSS CLI' >> "$profile"
        echo "export PATH=\"\$HOME/.macss/bin:\$PATH\"" >> "$profile"
        echo "Added PATH entry to $profile"
        break
    fi
done

echo "MACSS CLI $TAG installed. Reload your shell or run:"
echo "  export PATH=\"\$HOME/.macss/bin:\$PATH\""
echo "  macss"
