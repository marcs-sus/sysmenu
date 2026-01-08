#!/bin/bash
set -euo pipefail

# Uninstallation script for sysmenu

INSTALL_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
SCRIPT_DEST_NAME="sysmenu"
DESKTOP_FILE_NAME="sysmenu.desktop"

echo "Uninstalling sysmenu..."

# Remove the installed script
if [ -f "$INSTALL_DIR/$SCRIPT_DEST_NAME" ]; then
    echo "Removing script from $INSTALL_DIR..."
    rm -f "$INSTALL_DIR/$SCRIPT_DEST_NAME"
else
    echo "Script not found at $INSTALL_DIR/$SCRIPT_DEST_NAME"
fi

# Remove the desktop entry
if [ -f "$APP_DIR/$DESKTOP_FILE_NAME" ]; then
    echo "Removing desktop entry from $APP_DIR..."
    rm -f "$APP_DIR/$DESKTOP_FILE_NAME"
else
    echo "Desktop entry not found at $APP_DIR/$DESKTOP_FILE_NAME"
fi

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    echo "Updating desktop database..."
    update-desktop-database "$APP_DIR"
fi

echo "✓ Uninstallation complete!"
echo ""
echo "sysmenu has been removed from your system."
