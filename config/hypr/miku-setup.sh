#!/usr/bin/env bash
# Miku Hyprland: one-time root setup. Run with:  sudo bash ~/.config/hypr/miku-setup.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
U_HOME=$(getent passwd "${SUDO_USER:?run with sudo from your normal user}" | cut -d: -f6)

echo "==> Installing Hyprland helpers (screen-share portal, screenshots, brightness)"
pacman -S --needed --noconfirm xdg-desktop-portal-hyprland grim slurp wl-clipboard brightnessctl

echo "==> Making wallpaper + Miku cursor readable by the login screen"
install -Dm644 "$U_HOME/Pictures/Wallpapers/miku-01.png" /usr/share/backgrounds/miku/miku-01.png
rm -rf /usr/share/icons/miku-cursor-linux
cp -r "$U_HOME/.local/share/icons/miku-cursor-linux" /usr/share/icons/
chmod -R a+rX /usr/share/icons/miku-cursor-linux

echo "==> Installing Miku GTK theme for the greeter"
install -d /usr/share/themes/Miku-Greeter/gtk-3.0
cat > /usr/share/themes/Miku-Greeter/gtk-3.0/gtk.css <<'CSS'
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");

@define-color miku_teal #39c5bb;
@define-color miku_pink #e12885;
@define-color miku_bg   rgba(11, 20, 22, 0.82);
@define-color miku_text #e0f4f2;

#panel_window {
  background: rgba(11, 20, 22, 0.55);
  color: @miku_text;
  border-bottom: 2px solid @miku_teal;
}
#panel_window menubar, #panel_window menubar > menuitem { color: @miku_text; background: transparent; }
#panel_window menubar > menuitem:hover { background: alpha(@miku_teal, 0.25); border-radius: 8px; }

#login_window, #restart_dialog, #shutdown_dialog {
  background: @miku_bg;
  color: @miku_text;
  border: 2px solid @miku_teal;
  border-radius: 18px;
  box-shadow: 0 0 24px alpha(@miku_teal, 0.45);
  padding: 8px;
}
#login_window #user_image { border-radius: 50%; border: 3px solid @miku_pink; }
#login_window entry {
  background: rgba(20, 35, 42, 0.9);
  color: @miku_text;
  border: 1px solid #3d6066;
  border-radius: 10px;
  caret-color: @miku_teal;
}
#login_window entry:focus { border-color: @miku_teal; box-shadow: 0 0 0 2px alpha(@miku_teal, 0.35); }
#login_window button { border-radius: 10px; }
#login_window #login_button, #login_window button.suggested-action {
  background: linear-gradient(90deg, @miku_teal, @miku_pink);
  color: #002522;
  font-weight: bold;
  border: none;
}
menu, .menu { background: @miku_bg; color: @miku_text; border: 1px solid @miku_teal; border-radius: 10px; }
menuitem:hover { background: alpha(@miku_teal, 0.3); }
CSS

echo "==> Writing /etc/lightdm/lightdm-gtk-greeter.conf (backup: .bak)"
[[ -f /etc/lightdm/lightdm-gtk-greeter.conf.bak ]] || cp /etc/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf.bak
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<'CONF'
[greeter]
background = /usr/share/backgrounds/miku/miku-01.png
user-background = false
theme-name = Miku-Greeter
icon-theme-name = Adwaita
cursor-theme-name = miku-cursor-linux
cursor-theme-size = 24
font-name = JetBrainsMono Nerd Font 11
clock-format = %a %d %b  %H:%M
position = 50%,center 55%,center
indicators = ~host;~spacer;~session;~clock;~spacer;~power
CONF

echo "Done. The session picker (niri / Hyprland) is in the top bar of the login screen."
