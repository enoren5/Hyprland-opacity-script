#!/usr/bin/env bash

# File to store opacities
STATE_FILE="/tmp/hypr_opacity_state"
mkdir -p /tmp
touch "$STATE_FILE"

ADDR=$(hyprctl activewindow -j | jq -r '.address')
[[ -z "$ADDR" || "$ADDR" == "null" ]] && {
    notify-send "Opacity Script" "No active window found."
    exit 1
}

# Default opacity
OPACITY=1.0

# Get stored opacity for this window
if grep -q "$ADDR" "$STATE_FILE"; then
    OPACITY=$(grep "$ADDR" "$STATE_FILE" | cut -d' ' -f2)
fi

# Adjust opacity
STEP=0.1
MIN_OPACITY=0.1
MAX_OPACITY=1.0

case "$1" in
  --decrease)
    OPACITY=$(echo "$OPACITY - $STEP" | bc)
    (( $(echo "$OPACITY < $MIN_OPACITY" | bc -l) )) && OPACITY=$MIN_OPACITY
    ;;
  --increase)
    OPACITY=$(echo "$OPACITY + $STEP" | bc)
    (( $(echo "$OPACITY > $MAX_OPACITY" | bc -l) )) && OPACITY=$MAX_OPACITY
    ;;
  --reset)
    OPACITY=$MAX_OPACITY
    ;;
  *)
    notify-send "Opacity Script" "Usage: $0 [--increase|--decrease|--reset]"
    exit 1
    ;;
esac

# Apply opacity
hyprctl dispatch setprop "address:$ADDR" alpha "$OPACITY"

# Save updated value
grep -v "$ADDR" "$STATE_FILE" > "$STATE_FILE.tmp"
echo "$ADDR $OPACITY" >> "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"

# Notify
notify-send "Opacity Script" "Set to $OPACITY"

