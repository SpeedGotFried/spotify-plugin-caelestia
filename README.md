<div align="center">

# 🎵 spotify-plugin-caelestia

**Spotify album art wallpaper daemon for the [Caelestia](https://github.com/caelestia-dots/shell) shell**

*Event-driven • Zero CPU polling • Fully configurable • Album-matched colour schemes*

</div>

---

When you play a track on Spotify, this plugin:
1. Fetches the album art
2. Blurs + darkens it to create a full-screen background
3. Composites a rounded album art card with track title and artist
4. Pushes it to your wallpaper via `caelestia shell wallpaper set`
5. *(Optional)* Extracts the dominant album colour and applies it as your global caelestia colour scheme
6. Restores your original wallpaper **and** colour scheme when Spotify pauses or closes

Uses `playerctl --follow` — **no polling loop**, reacts instantly to track changes.

---

## Dependencies

| Package | Purpose |
|---|---|
| `playerctl` | Reads Spotify metadata via MPRIS |
| `imagemagick` | Builds the composite wallpaper |
| `curl` | Downloads album art |
| `python3` | Parses `hyprctl monitors` JSON |
| `hyprctl` | Gets monitor resolution |
| `caelestia` | Sets the wallpaper |

Install all at once (Arch):
```bash
paru -S playerctl imagemagick curl python hyprland caelestia-cli
```

---

## Install

```bash
git clone https://github.com/SpeedGotFried/spotify-plugin-caelestia
cd spotify-plugin-caelestia
./install.sh
```

The installer will:
- Check all dependencies
- Copy the script to `~/.local/bin/spotify-wallpaper`
- Copy the default config to `~/.config/caelestia/spotify-plugin.conf`
- Install and enable a `systemd --user` service (starts automatically with your session)

### Uninstall

```bash
./install.sh --uninstall
```

---

## Configuration

Edit `~/.config/caelestia/spotify-plugin.conf`:

```bash
# Choose your fonts
FONT_BOLD="/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf"
FONT_REGULAR="/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"

# Album art size (pixels)
COVER_SIZE=480

# Background blur strength
BLUR_STRENGTH=30

# Vertical offset of the art from screen centre (negative = shift up)
VERTICAL_OFFSET=-80

# ── Match Scheme ─────────────────────────────────────────────────
# Set to `true` to automatically apply a caelestia colour scheme
# that matches the dominant colour of the current album art.
MATCH_SCHEME=false

# Force dark or light mode when Match Scheme is active.
# Keeping this as `dark` means only dark themes are ever applied.
SCHEME_MODE=dark

# Caelestia scheme variant (tonalspot, vibrant, expressive, …)
SCHEME_VARIANT=tonalspot
```

Changes take effect on the next track change. No restart needed.

---

## Usage

```bash
# View live logs
journalctl --user -u spotify-wallpaper -f

# Stop / start / restart
systemctl --user stop spotify-wallpaper
systemctl --user start spotify-wallpaper
systemctl --user restart spotify-wallpaper

# Check status
systemctl --user status spotify-wallpaper
```

---

## Project Structure

```
spotify-plugin-caelestia/
├── install.sh                        # Install / uninstall
├── src/
│   └── spotify-wallpaper             # Main daemon
├── systemd/
│   └── spotify-wallpaper.service     # systemd --user service
└── config/
    └── spotify-plugin.conf           # Default config (copied on install)
```

---

## How It Works

```
Spotify changes track
       ↓
playerctl --follow emits a line
       ↓
Parse: status / trackid / artUrl / artist / title
       ↓
Download album art  →  build wallpaper with ImageMagick
       ↓
caelestia shell wallpaper set <path>
       ↓
[MATCH_SCHEME=true] Extract dominant hex colour from album art
       ↓
caelestia scheme set -n dynamic -f <hex> -m dark -v <variant>
       ↓
On pause/close → restore original wallpaper + original scheme
```

Wallpapers are cached in `~/.cache/spotify-plugin-caelestia/` by track ID, so each track only needs to be built once.

---

## License

MIT
