#!/usr/bin/env bash
# Shows the current kitty colour palette (used in the showcase video instead of htop).
mode=$(desktop-mode status 2>/dev/null || echo miku)
printf '\n  \e[1;35m♪\e[0m \e[1m%s-Palette\e[0m\n\n' "${mode^}"
for row in 0 8; do
    for _ in 1 2 3; do
        printf '  '
        for i in $(seq $row $((row + 7))); do printf '\e[48;5;%sm      \e[0m ' "$i"; done
        printf '\n'
    done
    printf '\n'
done
printf '  '
for i in $(seq 1 6); do printf '\e[3%sm■ \e[0m' "$i"; done
printf '\n'
