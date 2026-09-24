#!/bin/bash
set -e

PLUGIN_ID="io.github.yanuarpmbd.winvm"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

echo "=== Installing Omarchy Windows VM Widget ($PLUGIN_ID) ==="

# Step 1: Validate plugin
echo "Validating plugin files..."
omarchy plugin validate "$PLUGIN_DIR"
if command -v qmllint >/dev/null 2>&1; then
  echo "Checking QML with qmllint..."
  qmllint -I "${OMARCHY_PATH:-/usr/share/omarchy}/shell" \
    "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml" "$PLUGIN_DIR/WinVmService.qml"
fi

# Step 2: Target directory sync
echo "Installing to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"
cp -f "$PLUGIN_DIR/manifest.json" "$TARGET_DIR/"
cp -f "$PLUGIN_DIR/BarWidget.qml" "$TARGET_DIR/"
cp -f "$PLUGIN_DIR/Panel.qml" "$TARGET_DIR/"
cp -f "$PLUGIN_DIR/WinVmService.qml" "$TARGET_DIR/"
cp -f "$PLUGIN_DIR/winvm-launcher.sh" "$TARGET_DIR/"
chmod +x "$TARGET_DIR/winvm-launcher.sh"
cp -f "$PLUGIN_DIR/README.md" "$TARGET_DIR/"
[[ -f "$PLUGIN_DIR/LICENSE" ]] && cp -f "$PLUGIN_DIR/LICENSE" "$TARGET_DIR/"

# Step 3: Rescan and enable plugin
echo "Registering plugin with Omarchy..."
omarchy-shell shell rescanPlugins 2>/dev/null || true

echo "Enabling plugin on right section..."
omarchy plugin enable "$PLUGIN_ID" --section right 2>/dev/null || true

# Step 4: Restart shell to apply changes
echo "Restarting Omarchy shell..."
omarchy-restart-shell

echo "✅ $PLUGIN_ID installed and activated successfully!"
