#!/usr/bin/env bash
# dev-install.sh — Build from source and install MACSS CLI locally (Linux)
#
# Usage: bash scripts/dev-install.sh
# Run from code/cli/

set -euo pipefail

INSTALL_DIR="$HOME/.macss"
BIN_DIR="$INSTALL_DIR/bin"

echo "Building macss CLI..."
dart pub get
dart compile exe bin/main.dart -o bin/macss

echo "Installing to $INSTALL_DIR..."

mkdir -p "$BIN_DIR" "$INSTALL_DIR/assets"
cp bin/macss "$BIN_DIR/macss"
chmod +x "$BIN_DIR/macss"
[[ -d assets ]] && cp -r assets/* "$INSTALL_DIR/assets/"

# Symlink alias: ma → macss
ln -sf "$BIN_DIR/macss" "$BIN_DIR/ma"

# Add to PATH in shell profile if needed
for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [[ -f "$profile" ]] && ! grep -q 'macss/bin' "$profile"; then
        echo '' >> "$profile"
        echo '# MACSS CLI' >> "$profile"
        echo "export PATH=\"\$HOME/.macss/bin:\$PATH\"" >> "$profile"
        echo "Added PATH entry to $profile"
        break
    fi
done

echo "Done. Reload your shell or run: export PATH=\"\$HOME/.macss/bin:\$PATH\""
