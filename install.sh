#!/bin/bash
set -euo pipefail

# Installation script for sysmenu

RAW_GITHUB="https://raw.githubusercontent.com/marcs-sus/sysmenu/"
INSTALL_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
SCRIPT_SRC="sysmenu.sh"
SCRIPT_DEST_NAME="sysmenu"
DESKTOP_FILE_NAME="sysmenu.desktop"

echo "Installing sysmenu..."

# Function to check if a command is available
require_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: $1 is required but not installed"
        exit 1
    fi
}

# Commands required for this script
require_command fzf
require_command curl
require_command systemctl
require_command journalctl
require_command sudo
require_command awk

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$APP_DIR"

# Download and install sysmenu script
echo "Downloading sysmenu script..."
curl -fsSL "$RAW_GITHUB/master/$SCRIPT_SRC" -o "$INSTALL_DIR/$SCRIPT_DEST_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_DEST_NAME"

# Ensure the directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Warning: $INSTALL_DIR is not in your PATH."
    echo "You may want to add the following line to your shell configuration (e.g., ~/.bashrc, ~/.zshrc, etc.):"
    echo "export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
fi

# Download and install desktop entry
echo "Installing desktop entry..."
curl -fsSL "$RAW_GITHUB/master/$DESKTOP_FILE_NAME" -o "$APP_DIR/$DESKTOP_FILE_NAME"

# Update desktop entry HOME path
sed -i "s|<HOME>|$HOME|g" "$APP_DIR/$DESKTOP_FILE_NAME"

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$APP_DIR"
fi

echo "✓ Installation complete!"
echo ""
echo "You can use it by running 'sysmenu' from the terminal or launching 'System Menu' from your application menu."
echo ""
echo "Optional dependencies for better experience:"
echo "  - gum: https://github.com/charmbracelet/gum"
echo "  - bat: https://github.com/sharkdp/bat"
echo ""
echo "To uninstall, run:"
echo "curl -fsSL $RAW_GITHUB/master/uninstall.sh | bash"
