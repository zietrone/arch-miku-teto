#!/usr/bin/env bash
# Arch Linux · Miku / Teto desktop — installer
#
#   ./install.sh            full install (packages, configs, login screen)
#   ./install.sh --no-pkgs  skip pacman, only copy configs + login screen
#   ./install.sh --no-greeter  skip the LightDM login screen part
#
# Run as your normal user (NOT root). sudo is asked for when needed.
# Existing configs are moved to ~/.config-backup-<date> before anything is overwritten.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
BACKUP=$HOME/.config-backup-$(date +%Y-%m-%d_%H%M%S)
DO_PKGS=true DO_GREETER=true
for a in "$@"; do
    case $a in
        --no-pkgs) DO_PKGS=false ;;
        --no-greeter) DO_GREETER=false ;;
        -h|--help) sed -n 2,9p "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

[[ $EUID -ne 0 ]] || { echo "Bitte als normaler User starten, nicht als root."; exit 1; }
[[ -f /etc/arch-release ]] || echo "Warnung: das sieht nicht nach Arch Linux aus – weiter auf eigene Gefahr."

say() { printf '\e[38;2;57;197;187m==>\e[0m %s\n' "$*"; }

PKGS=(
    # compositors + shell
    niri hyprland dux-shell quickshell accountsservice
    xdg-desktop-portal-gnome xdg-desktop-portal-hyprland
    # terminal + tools
    kitty alacritty fastfetch nautilus
    grim slurp wl-clipboard brightnessctl
    python python-pillow python-gobject
    # login screen
    lightdm lightdm-gtk-greeter
    # font
    ttf-jetbrains-mono-nerd
)

if $DO_PKGS; then
    say "Pakete installieren (pacman)"
    sudo pacman -Syu --needed "${PKGS[@]}"
fi

backup() {  # move an existing path into the backup dir
    local p=$1
    [[ -e $p || -L $p ]] || return 0
    local rel=${p#"$HOME"/}
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$p" "$BACKUP/$rel"
}

say "Configs nach $CFG kopieren (Backup: $BACKUP)"
mkdir -p "$CFG"
for d in niri hypr kitty alacritty fastfetch environment.d mikuteto-greeter dms; do
    backup "$CFG/$d"
    cp -a "$REPO/config/$d" "$CFG/$d"
done
# DMS reads ~/.config/DankMaterialShell -> same folder as ~/.config/dms
backup "$CFG/DankMaterialShell"; ln -sfn dms "$CFG/DankMaterialShell"
# paths inside DMS settings point at your own home
sed -i "s#__HOME__#$HOME#g" "$CFG/dms/settings.json"
[[ -f $CFG/desktop-mode ]] || cp "$REPO/config/desktop-mode" "$CFG/desktop-mode"

say "Scripts nach ~/.local/bin"
install -Dm755 "$REPO/local/bin/desktop-mode"  "$HOME/.local/bin/desktop-mode"
install -Dm755 "$REPO/local/bin/mini-miku-png" "$HOME/.local/bin/mini-miku-png"

say "Cursor (Miku + Teto) nach ~/.local/share/icons"
mkdir -p "$HOME/.local/share/icons/default"
for c in miku-cursor-linux teto-cursor-linux; do
    rm -rf "$HOME/.local/share/icons/$c"
    cp -a "$REPO/local/share/icons/$c" "$HOME/.local/share/icons/"
done
printf '[Icon Theme]\nInherits=miku-cursor-linux\n' > "$HOME/.local/share/icons/default/index.theme"

say "Wallpaper nach ~/Pictures/Wallpapers"
mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"
cp "$REPO"/wallpapers/* "$HOME/Pictures/Wallpapers/"

say "~/.bashrc (Miku/Teto Prompt)"
backup "$HOME/.bashrc"; cp "$REPO/bashrc" "$HOME/.bashrc"

say "DMS mit niri starten"
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user add-wants niri.service dms.service 2>/dev/null || echo "   (übersprungen – wird beim ersten Login nachgeholt)"

# apply the saved mode once so every file is consistent
"$HOME/.local/bin/desktop-mode" "$(cat "$CFG/desktop-mode")" --login || true

if $DO_GREETER; then
    say "Login-Screen einrichten (braucht sudo)"
    sudo bash "$CFG/hypr/miku-setup.sh"     # Hyprland helpers + lightdm-gtk-greeter fallback theme
    sudo bash "$CFG/hypr/teto-setup.sh"     # Miku/Teto sessions + mikuteto-greeter
    if systemctl is-enabled -q lightdm 2>/dev/null; then
        :
    elif systemctl is-enabled -q display-manager 2>/dev/null; then
        echo "   Ein anderer Display-Manager ist aktiv. Zum Wechseln:"
        echo "     sudo systemctl disable display-manager && sudo systemctl enable lightdm"
    else
        sudo systemctl enable lightdm
    fi
fi

echo
say "Fertig ♪  Neu starten / abmelden und im Login-Screen Miku oder Teto wählen (F2 wechselt)."
say "Im laufenden System umschalten:  desktop-mode miku | teto | toggle"
[[ -d $BACKUP ]] && say "Deine alten Dateien liegen in $BACKUP"
