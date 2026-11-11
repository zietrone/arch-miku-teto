#!/usr/bin/env bash
# Records an automated preview video of the Miku/Teto Hyprland setup,
# then adds intro/outro cards and captions with ffmpeg.
# Recording is paused while DMS restarts during a theme switch, so the
# video has no blank frames.
# Usage: showcase/record-showcase.sh [output.mp4]
set -uo pipefail

OUT=${1:-$HOME/Videos/miku-teto-preview-$(date +%Y%m%d-%H%M%S).mp4}
HERE=$(cd "$(dirname "$0")" && pwd)
WS=5                                   # empty workspace used for the demo
START_MODE=$(desktop-mode status)
TMP=$(mktemp -d)
SEG=0                                  # current segment: $TMP/seg$SEG.{mp4,caps}

dms_ipc() { dms ipc call "$@" >/dev/null 2>&1; }
hd() { hyprctl dispatch "$1" >/dev/null; }
ws() { hd "hl.dsp.focus({ workspace = $1 })"; }
term() { setsid -f kitty --class showcase -e bash -ic "$1; exec bash" >/dev/null 2>&1; }
# fastfetch like the repo's bashrc: Miku = text-art, Teto = pixel picture
# (independent of the local ~/.bashrc, so no private pictures end up in the video)
FF='if [[ $(<~/.config/desktop-mode) == teto ]]; then command fastfetch --logo-type kitty-direct --logo ~/.config/fastfetch/images/teto-pixel.png --logo-width 34 --logo-height 17 --logo-padding-top 1; else command fastfetch; fi'
closeterms() { pkill -f "kitty --class showcase"; sleep 1; }
now() { awk -v a="$EPOCHREALTIME" -v b="$T0" 'BEGIN{printf "%.2f", a-b}'; }
cap_start=""; cap_text=""
cap() {   # cap "text" starts a caption, cap "" ends the current one
    local t; t=$(now)
    [[ -n $cap_text ]] && echo "$cap_start $t $cap_text" >>"$TMP/seg$SEG.caps"
    cap_start=$t; cap_text=$1
}
rec_start() {
    SEG=$((SEG+1)); : >"$TMP/seg$SEG.caps"
    wf-recorder -y -f "$TMP/seg$SEG.mp4" -c libx264 -p preset=veryfast -p crf=18 -r 60 >/dev/null 2>&1 &
    REC=$!; sleep 0.8; T0=$EPOCHREALTIME
}
rec_stop() { cap ""; sleep 0.4; kill -INT "$REC"; wait "$REC"; REC=; }
switch_mode() {   # switch theme off-camera and wait until DMS has redrawn
    desktop-mode "$1" >/dev/null
    for _ in $(seq 40); do dms_ipc notifications enableDoNotDisturbIndefinitely && break; sleep 0.5; done
    sleep 4; ws "$WS"; sleep 1
}

# Privacy: hide the bar's weather widget (its location comes from your IP)
# while recording; it is put back afterwards.
DMS_SETTINGS=${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/settings.json
WEATHER_HIDDEN=false
dms_wait() { for _ in $(seq 40); do dms_ipc notifications enableDoNotDisturbIndefinitely && break; sleep 0.5; done; sleep 2; }
weather_widget() {   # weather_widget hide|show
    systemctl --user stop dms; sleep 0.5
    python3 -I - "$DMS_SETTINGS" "$1" <<'PY'
import json, sys
path, action = sys.argv[1:]
with open(path) as f: data = json.load(f)
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "centerWidgets" and isinstance(v, list):
                if action == "hide":
                    v[:] = [w for w in v if w != "weather"]
                elif "weather" not in v:
                    v.insert(v.index("clock") + 1 if "clock" in v else len(v), "weather")
            else: walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(data)
with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
PY
    systemctl --user start dms; dms_wait
}

for c in wf-recorder ffmpeg; do command -v $c >/dev/null || { echo "$c fehlt"; exit 1; }; done
mkdir -p "$(dirname "$OUT")"

cleanup() {
    pkill -f "kitty --class showcase"
    [[ -n ${REC:-} ]] && kill -INT "$REC" 2>/dev/null && wait "$REC"
    [[ $(desktop-mode status) != "$START_MODE" ]] && desktop-mode "$START_MODE" >/dev/null && dms_wait
    $WEATHER_HIDDEN && weather_widget show
    dms_ipc notifications disableDoNotDisturb
    rm -rf "$TMP"
}
trap cleanup EXIT

if grep -q '"weather"' "$DMS_SETTINGS"; then WEATHER_HIDDEN=true; weather_widget hide; fi
dms_ipc notifications enableDoNotDisturbIndefinitely
[[ $START_MODE != miku ]] && switch_mode miku
ws "$WS"; sleep 1.5

# ── segment 1: Miku ──────────────────────────────────────────────────────────
rec_start
cap "Miku-Modus  ·  Hyprland + DankMaterialShell"; sleep 3.5

cap "kitty  ·  fastfetch  ·  Miku-Prompt"
term "clear; $FF"; sleep 3
term "clear; cmatrix -C cyan -b"; sleep 2.5
term "clear; bash '$HERE/palette.sh'"; sleep 3
cap ""; sleep 0.5

cap "DankMaterialShell  ·  Launcher"
dms_ipc spotlight openQuery kitty; sleep 2.5; dms_ipc spotlight close; sleep 0.8
cap "DankMaterialShell  ·  Wallpaper-Auswahl"
dms_ipc dash open wallpaper; sleep 3.5; dms_ipc dash close; sleep 0.8

cap "Workspace-Übersicht"
dms_ipc hypr openOverview; sleep 3.5; dms_ipc hypr closeOverview; sleep 1
cap "\$ desktop-mode teto"; sleep 2
rec_stop; closeterms

# ── segment 2: Teto ──────────────────────────────────────────────────────────
switch_mode teto
rec_start
cap "Teto-Modus  ·  Rot + Gold  ·  ein Befehl"; sleep 3
term "clear; $FF"; sleep 3
term "clear; cmatrix -C red -b"; sleep 3
term "clear; bash '$HERE/palette.sh'"; sleep 3
cap "Teto-Modus  ·  Wallpaper + Launcher"
dms_ipc dash open wallpaper; sleep 3; dms_ipc dash close; sleep 0.8
dms_ipc spotlight openQuery kitty; sleep 2.5; dms_ipc spotlight close; sleep 1
cap "\$ desktop-mode miku"; sleep 2
rec_stop; closeterms

# ── segment 3: back to Miku ─────────────────────────────────────────────────
switch_mode miku
rec_start
cap "Zurück zu Miku  ·  jederzeit umschaltbar"
term "clear; $FF"; sleep 4
rec_stop; closeterms

# ── post-processing: captions + intro/outro cards ───────────────────────────
FONT=$(fc-match -f '%{file}' 'JetBrainsMono Nerd Font:style=Bold')
FONTR=$(fc-match -f '%{file}' 'JetBrainsMono Nerd Font:style=Regular')
esc() { sed -e 's/\\/\\\\\\\\/g' -e "s/'/\\\\\\\\'/g" -e 's/:/\\\\:/g' -e 's/%/\\\\%/g' <<<"$1"; }
ENC=(-c:v libx264 -crf 18 -preset medium -r 60 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2)

card() {  # card <wallpaper> <out> <title> <subtitle> <accent>
    ffmpeg -v error -y -loop 1 -t 4 -i "$1" -f lavfi -t 4 -i anullsrc=r=48000:cl=stereo -filter_complex "
      [0:v]scale=1920:1080,boxblur=12:2,eq=brightness=-0.18,
      drawtext=fontfile=$FONT:text='$(esc "$3")':fontsize=84:fontcolor=white:x=(w-tw)/2:y=(h/2)-90,
      drawtext=fontfile=$FONTR:text='$(esc "$4")':fontsize=38:fontcolor=$5:x=(w-tw)/2:y=(h/2)+30,
      fps=60,fade=in:0:20,fade=out:st=3.5:d=0.5[v]" \
      -map '[v]' -map 1:a "${ENC[@]}" -shortest "$2"
}
card "$HERE/../wallpapers/miku-01.png" "$TMP/intro.mp4" "Arch Linux · Miku / Teto" \
     "niri + Hyprland  ·  DankMaterialShell  ·  2 Themes" "0x39c5bb"
card "$HERE/../wallpapers/teto-01.png" "$TMP/outro.mp4" "github.com/zietrone/arch-miku-teto" \
     "git clone … && ./install.sh" "0xf2b25c"

echo "file '$TMP/intro.mp4'" >"$TMP/list.txt"
for i in $(seq "$SEG"); do
    d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMP/seg$i.mp4")
    f=""
    while read -r s e text; do
        f+="drawtext=fontfile=$FONT:text='$(esc "$text")':fontsize=40:fontcolor=white:box=1:boxcolor=0x0d1b1e@0.78:boxborderw=22:x=(w-tw)/2:y=h-150:alpha='if(lt(t,$s+0.3),(t-$s)/0.3,if(gt(t,$e-0.3),($e-t)/0.3,1))':enable='between(t,$s,$e)',"
    done <"$TMP/seg$i.caps"
    ffmpeg -v error -y -i "$TMP/seg$i.mp4" -f lavfi -i anullsrc=r=48000:cl=stereo \
        -vf "${f}fps=60,fade=in:st=0:d=0.4,fade=out:st=$(awk -v d="$d" 'BEGIN{print d-0.4}'):d=0.4" \
        -map 0:v -map 1:a "${ENC[@]}" -shortest "$TMP/main$i.mp4"
    echo "file '$TMP/main$i.mp4'" >>"$TMP/list.txt"
done
echo "file '$TMP/outro.mp4'" >>"$TMP/list.txt"

ffmpeg -v error -y -f concat -safe 0 -i "$TMP/list.txt" -c:v libx264 -crf 20 -preset medium \
    -c:a aac -movflags +faststart "$OUT"
echo "Video: $OUT"
