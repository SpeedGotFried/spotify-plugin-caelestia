#!/bin/bash
# install.sh — spotify-plugin-caelestia installer
# Usage: ./install.sh [--uninstall]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE="spotify-wallpaper"

# ─── Colours ─────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*"; }

# ─── Uninstall ───────────────────────────────────────────────────
if [[ "$1" == "--uninstall" ]]; then
    echo "Uninstalling spotify-plugin-caelestia..."
    systemctl --user disable --now "$SERVICE" 2>/dev/null && ok "Service stopped and disabled" || true
    rm -f "$BIN_DIR/spotify-wallpaper"             && ok "Removed binary"
    rm -f "$SYSTEMD_DIR/${SERVICE}.service"        && ok "Removed service file"
    systemctl --user daemon-reload
    echo ""
    warn "Config kept at: $CONFIG_DIR/spotify-plugin.conf"
    warn "Cache kept at: ${XDG_CACHE_HOME:-$HOME/.cache}/spotify-plugin-caelestia/"
    warn "Remove manually if you no longer need them."
    exit 0
fi

# ─── Dependency check ────────────────────────────────────────────
echo "Checking dependencies..."
deps=(playerctl magick hyprctl caelestia curl python3)
missing=()
for dep in "${deps[@]}"; do
    if command -v "$dep" &>/dev/null; then
        ok "$dep"
    else
        err "$dep — NOT FOUND"
        missing+=("$dep")
    fi
done

if (( ${#missing[@]} > 0 )); then
    echo ""
    err "Missing: ${missing[*]}"
    echo "Install them first (e.g. via pacman/paru), then re-run this script."
    exit 1
fi

echo ""
echo "Installing spotify-plugin-caelestia..."

# ─── Binary ──────────────────────────────────────────────────────
mkdir -p "$BIN_DIR"
install -m 755 "$SCRIPT_DIR/src/spotify-wallpaper" "$BIN_DIR/spotify-wallpaper"
ok "Installed binary → $BIN_DIR/spotify-wallpaper"

# Ensure ~/.local/bin is on PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in your PATH. Add it to your shell's config file."
fi

# ─── Config ──────────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/spotify-plugin.conf" ]]; then
    install -m 644 "$SCRIPT_DIR/config/spotify-plugin.conf" "$CONFIG_DIR/spotify-plugin.conf"
    ok "Installed config → $CONFIG_DIR/spotify-plugin.conf"
else
    warn "Config already exists — skipping (edit manually if needed): $CONFIG_DIR/spotify-plugin.conf"
fi

# ─── Systemd service ─────────────────────────────────────────────
mkdir -p "$SYSTEMD_DIR"
install -m 644 "$SCRIPT_DIR/systemd/${SERVICE}.service" "$SYSTEMD_DIR/${SERVICE}.service"
ok "Installed service → $SYSTEMD_DIR/${SERVICE}.service"

systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE"
ok "Service enabled and started"

# ─── Done ────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}All done!${NC} spotify-plugin-caelestia is running."
echo ""
echo "  Config:  $CONFIG_DIR/spotify-plugin.conf"
echo "  Logs:    journalctl --user -u $SERVICE -f"
echo "  Stop:    systemctl --user stop $SERVICE"
echo "  Start:   systemctl --user start $SERVICE"
echo "  Remove:  $SCRIPT_DIR/install.sh --uninstall"
