#!/usr/bin/env bash

# A simple script to adjust opacity per window using alphaoverride in Hyprland

LOG_FILE="/tmp/hypr_opacity.log"
STEP=0.1
MIN=0.1
MAX=1.0

# Logging helper
log() {
    echo "[$(date)] $1" >> "$LOG_FILE"
}

# Notify helper
notify() {
    notify-send "Opacity Script" "$1"
}

# Get active window address
ADDR=$(hyprctl activewindow -j | jq -r '.address')

if [[ -z "$ADDR" || "$ADDR" == "null" ]]; then
    log "No active window found"
    notify "No active window"
    exit 1
fi

# Reset option
if [[ "$1" == "--reset" ]]; then
    hyprctl dispatch setprop address:$ADDR alphaoverride -1
    log "Reset opacity for $ADDR"
    notify "Opacity reset to default"
    exit 0
fi

# Get current alphaoverride (if any), fallback to 1.0
CURRENT=$(hyprctl getprop address:$ADDR alphaoverride -j | jq -r '.value // "1.0"')

if [[ -z "$CURRENT" || "$CURRENT" == "null" ]]; then
    CURRENT=1.0
fi

# Determine new opacity
if [[ "$1" == "--decrease" ]]; then
    NEW=$(echo "$CURRENT - $STEP" | bc)
    COMP=$(echo "$NEW < $MIN" | bc)
    [[ "$COMP" -eq 1 ]] && NEW=$MIN
elif [[ "$1" == "--increase" ]]; then
    NEW=$(echo "$CURRENT + $STEP" | bc)
    COMP=$(echo "$NEW > $MAX" | bc)
    [[ "$COMP" -eq 1 ]] && NEW=$MAX
else
    notify "Usage: $0 --increase | --decrease | --reset"
    exit 1
fi

# Apply new value
hyprctl dispatch setprop address:$ADDR alphaoverride "$NEW"
log "Set opacity for $ADDR to $NEW"
notify "Window opacity: $NEW"

