# Arch Linux · Miku / Teto Desktop ♪

Meine Arch-Linux-Dotfiles mit zwei Themes, zwischen denen man jederzeit wechseln kann:

| Modus | Farben | Extras |
|-------|--------|--------|
| **Miku** | Türkis `#39c5bb` + Pink `#e12885` | Miku-Cursor, Pixel-Miku mit Lauch im Prompt |
| **Teto** | Rot `#e0405b` + Gold `#f2b25c` | Teto-Cursor, Pixel-Teto mit Baguette im Prompt |

**Enthalten:** niri + Hyprland, DankMaterialShell (dux-shell), kitty, alacritty, fastfetch,
Bash-Prompt, Wallpaper, Cursor und ein eigener **LightDM-Login-Screen
(`mikuteto-greeter`)** mit Miku | Teto-Schalter.

## Installation

```bash
git clone <repo-url> ~/arch-miku-teto
cd ~/arch-miku-teto
./install.sh
```

Optionen: `--no-pkgs` (keine Pakete installieren), `--no-greeter` (Login-Screen weglassen).
Vorhandene Configs werden vorher nach `~/.config-backup-<datum>` verschoben.

## Benutzung

- **Login-Screen:** Button *Miku | Teto* oben auf der Login-Karte oder **F2**. Sessions:
  `Niri · Miku`, `Niri · Teto`, `Hyprland · Miku`, `Hyprland · Teto`.
- **Im laufenden System:** `desktop-mode miku`, `desktop-mode teto`, `desktop-mode toggle`
- Login-Screen wieder entfernen: `sudo bash ~/.config/hypr/teto-setup.sh --remove-greeter`
- **fastfetch-Bild (nur kitty):** Ein eigenes Miku-Bild als `~/.config/fastfetch/images/miku.png`
  ablegen. Ohne Bild zeigt fastfetch die Text-Art aus `miku.txt` / `teto.txt`.

## Aufbau

```
config/            -> ~/.config/...
  niri/ hypr/      Compositor-Configs (hypr/theme/{miku,teto}.lua)
  dms/             DankMaterialShell-Einstellungen + Themes
  kitty/ fastfetch/ alacritty/
  mikuteto-greeter/  Login-Screen (Python + GTK3, LightDM)
  hypr/miku-setup.sh, hypr/teto-setup.sh   System-Setup (sudo)
local/bin/         desktop-mode (Theme-Umschalter), mini-miku-png (Prompt-Sprite)
local/share/icons/ Miku- und Teto-Cursor
wallpapers/        miku-01 / teto-01 (PNG + SVG)
bashrc             Miku/Teto-Prompt
install.sh
```

## Credits

- **Miku-Cursor:** [hatsune-miku-windows-linux-cursors](https://github.com/supermariofps/hatsune-miku-windows-linux-cursors)
  von supermariofps. Der Teto-Cursor ist eine davon abgeleitete Version (umgefärbt, Bohrer-Zöpfe + Baguette).
- **DMS-Theme „Deep Dark“** (`config/dms/themes/deepdark/`) von viewerofall.
- Die Configs bauen auf [niri](https://github.com/YaLTeR/niri), [Hyprland](https://hyprland.org),
  [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), kitty, alacritty und
  [fastfetch](https://github.com/fastfetch-cli/fastfetch) auf.

Hatsune Miku © Crypton Future Media, INC. · Kasane Teto © TWINDRILL.
Inoffizielles Fan-Projekt, nicht mit den Rechteinhabern verbunden.
