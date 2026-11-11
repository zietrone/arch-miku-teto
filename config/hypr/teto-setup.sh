#!/usr/bin/env bash
# Teto mode: one-time root setup. Run with:  sudo bash ~/.config/hypr/teto-setup.sh
#
# - Adds "Niri · Teto", "Hyprland · Teto", "Niri · Miku", "Hyprland · Miku" sessions.
#   Each applies that theme (via ~/.local/bin/desktop-mode) and then starts the compositor.
# - Installs mikuteto-greeter: a login screen with a Miku | Teto button (or F2) that
#   re-themes the login screen and logs you into that mode. It opens in your last mode.
#   If it ever fails to start it hands over to lightdm-gtk-greeter.
#
# Undo the greeter (keeps the sessions):  sudo bash ~/.config/hypr/teto-setup.sh --remove-greeter
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
U=${SUDO_USER:?run with sudo from your normal user}
U_HOME=$(getent passwd "$U" | cut -d: -f6)
CONF=/etc/lightdm/lightdm.conf.d/50-mikuteto-greeter.conf

if [[ ${1:-} == --remove-greeter ]]; then
    rm -f "$CONF"
    echo "Greeter disabled; LightDM uses lightdm-gtk-greeter again from the next login screen."
    exit 0
fi

echo "==> Installing /usr/local/bin/desktop-mode-session"
install -Dm755 /dev/stdin /usr/local/bin/desktop-mode-session <<'SH'
#!/bin/sh
# Login-screen wrapper: apply the Miku/Teto theme, then start the compositor.
#   desktop-mode-session miku|teto <compositor command...>
mode=$1; shift
[ -x "$HOME/.local/bin/desktop-mode" ] && "$HOME/.local/bin/desktop-mode" "$mode" --login
exec "$@"
SH

echo "==> Adding Miku/Teto sessions to /usr/share/wayland-sessions"
session() {  # file name desktopnames exec
    cat > "/usr/share/wayland-sessions/$1.desktop" <<EOF
[Desktop Entry]
Name=$2
Comment=$2 theme
Exec=/usr/local/bin/desktop-mode-session $4
Type=Application
DesktopNames=$3
EOF
}
session niri-teto     "Niri · Teto"     niri     "teto niri-session"
session niri-miku     "Niri · Miku"     niri     "miku niri-session"
session hyprland-teto "Hyprland · Teto" Hyprland "teto /usr/bin/start-hyprland"
session hyprland-miku "Hyprland · Miku" Hyprland "miku /usr/bin/start-hyprland"

echo "==> Making wallpapers, cursors and font readable by the login screen"
install -Dm644 "$U_HOME/Pictures/Wallpapers/miku-01.png" /usr/share/backgrounds/miku/miku-01.png
install -Dm644 "$U_HOME/Pictures/Wallpapers/teto-01.png" /usr/share/backgrounds/teto/teto-01.png
for c in miku-cursor-linux teto-cursor-linux; do
    rm -rf "/usr/share/icons/$c"
    cp -r "$U_HOME/.local/share/icons/$c" /usr/share/icons/
    chmod -R a+rX "/usr/share/icons/$c"
done
if [[ -d $U_HOME/.local/share/fonts/JetBrainsMonoNerd ]]; then
    rm -rf /usr/local/share/fonts/JetBrainsMonoNerd
    install -d /usr/local/share/fonts
    cp -r "$U_HOME/.local/share/fonts/JetBrainsMonoNerd" /usr/local/share/fonts/
    chmod -R a+rX /usr/local/share/fonts/JetBrainsMonoNerd
    fc-cache -f /usr/local/share/fonts >/dev/null
fi

echo "==> Letting the login screen see your last mode (/var/lib/desktop-mode/$U)"
install -dm755 /var/lib/desktop-mode
[[ -f /var/lib/desktop-mode/$U ]] || install -m644 -o "$U" /dev/null "/var/lib/desktop-mode/$U"
cat "$U_HOME/.config/desktop-mode" 2>/dev/null > "/var/lib/desktop-mode/$U" || echo miku > "/var/lib/desktop-mode/$U"

echo "==> Installing mikuteto-greeter"
install -Dm644 "$U_HOME/.config/mikuteto-greeter/greeter.py"  /usr/local/share/mikuteto-greeter/greeter.py
install -Dm644 "$U_HOME/.config/mikuteto-greeter/greeter.css" /usr/local/share/mikuteto-greeter/greeter.css
install -Dm755 /dev/stdin /usr/local/bin/mikuteto-greeter <<'SH'
#!/bin/sh
exec /usr/bin/python3 -I /usr/local/share/mikuteto-greeter/greeter.py "$@"
SH
cat > /usr/share/xgreeters/mikuteto-greeter.desktop <<'EOF'
[Desktop Entry]
Name=Miku/Teto Greeter
Comment=LightDM greeter with a Miku | Teto mode switch
Exec=/usr/local/bin/mikuteto-greeter
Type=Application
EOF
install -Dm644 /dev/stdin "$CONF" <<'EOF'
# Added by ~/.config/hypr/teto-setup.sh (remove with: --remove-greeter)
[Seat:*]
greeter-session=mikuteto-greeter
EOF

echo
echo "Done. Log out to see the new login screen: the Miku | Teto button is at the top of the login card (F2 also toggles)."
echo "If anything looks wrong:  sudo bash $U_HOME/.config/hypr/teto-setup.sh --remove-greeter"
