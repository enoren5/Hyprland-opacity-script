#!/usr/bin/env bash

LOG="/tmp/hypr_opacity.log"
ADDR=$(hyprctl activewindow -j | jq -r '.address')

CURRENT=$(hyprctl getprop address:$ADDR alphaoverride -j | jq -r '.value // "1.0"')
CURRENT=${CURRENT:-1.0}
CURRENT_INT=$(echo "$CURRENT * 100" | bc | cut -d'.' -f1)

if [[ "$1" == "--decrease" ]]; then
  NEW_INT=$((CURRENT_INT - 10))
  [[ $NEW_INT -lt 10 ]] && NEW_INT=10
elif [[ "$1" == "--increase" ]]; then
  NEW_INT=$((CURRENT_INT + 10))
  [[ $NEW_INT -gt 100 ]] && NEW_INT=100
elif [[ "$1" == "--reset" ]]; then
  hyprctl dispatch setprop address:$ADDR alphaoverride -1
  notify-send "Opacity Reset"
  echo "[$(date)] Reset for $ADDR" >> "$LOG"
  exit 0
else
  notify-send "Invalid argument"
  exit 1
fi

NEW=$(echo "scale=2; $NEW_INT / 100" | bc)
hyprctl dispatch setprop address:$ADDR alphaoverride "$NEW"
notify-send "Set opacity to $NEW"
echo "[$(date)] Set alphaoverride for $ADDR to $NEW" >> "$LOG"
