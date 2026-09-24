#!/bin/bash
set -e

PLUGIN_ID="io.github.yanuarpmbd.winvm"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

echo "=== Uninstalling Omarchy Windows VM Widget ($PLUGIN_ID) ==="

echo "Disabling plugin..."
omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true

echo "Removing plugin directory $TARGET_DIR..."
rm -rf "$TARGET_DIR"

echo "Restarting Omarchy shell..."
omarchy-restart-shell

echo "✅ $PLUGIN_ID has been uninstalled successfully."
