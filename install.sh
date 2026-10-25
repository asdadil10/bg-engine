#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  NerveCenter — install.sh
#  Installs / reinstalls the wallpaper plugin for the current user.
#  Usage:  ./install.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail

PLUGIN_ID="org.kde.nervecenter"
PLUGIN_DIR="$(dirname "$0")/nervecenter"

# Validate structure
if [[ ! -f "$PLUGIN_DIR/metadata.json" ]]; then
    echo "✗ metadata.json not found in $PLUGIN_DIR"
    exit 1
fi

echo "── NerveCenter installer ──────────────────────────────"

INSTALL_PATH="$HOME/.local/share/plasma/wallpapers/$PLUGIN_ID"

# Remove existing installation if present
if kpackagetool6 --type Plasma/Wallpaper -r "$PLUGIN_ID" 2>/dev/null; then
    echo "  ↻ Removed previous installation (kpackagetool6)"
elif [[ -d "$INSTALL_PATH" ]]; then
    rm -rf "$INSTALL_PATH"
    echo "  ↻ Removed stale installation directory"
fi

# Install fresh
kpackagetool6 --type Plasma/Wallpaper -i "$PLUGIN_DIR"
echo "  ✓ Installed $PLUGIN_ID"

# Remove keys that no current code path reads (audit item B4). This edits the
# shared plasmashell.conf as text so KConfig escaping is left untouched.
if command -v python3 >/dev/null 2>&1; then
    python3 "$(dirname "$0")/scripts/cleanup-legacy-settings.py"
else
    echo "  · python3 not found; skipping legacy settings cleanup"
fi

# Ensure legacy CAVA and PTY background service bridges are completely stopped and cleaned up
AUTOSTART_DIR="$HOME/.config/autostart"
rm -f "$AUTOSTART_DIR/nerve_pty.desktop" "$AUTOSTART_DIR/nerve_cava.desktop"
pgrep -f nerve_pty_bin | xargs -r kill -9 &>/dev/null || true
pgrep -f cava_server.py | xargs -r kill -9 &>/dev/null || true
pgrep -f "cava -p" | xargs -r kill -9 &>/dev/null || true
echo "  ✓ Cleaned up any legacy background service bridges (PTY and CAVA)"

echo ""
echo "  To activate:"
echo "    1. Right-click desktop → Configure Desktop and Wallpaper"
echo "    2. Select 'NerveCenter' from the wallpaper type dropdown"
echo ""
echo "  To hot-reload after code changes:"
echo "    kpackagetool6 --type Plasma/Wallpaper -u $PLUGIN_DIR"
echo "──────────────────────────────────────────────────────"
