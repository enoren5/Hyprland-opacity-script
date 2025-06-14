#!/usr/bin/env bash

# Hyprland Window Opacity Adjuster
# Requires: hyprctl, jq, bc, notify-send
# Adjusts persistent window opacity using `alpha` per window

LOG="/tmp/hypr_opacity_persist.log"
OPACITY_STEP=0.1
MIN_OPACITY=0.1
MAX_OPACITY=1.0

# Logging utility
log() {
    echo "$(date '+%F %T') - $*" >> "$LOG"
}

# Send notification
notify() {
    notify-send "Opacity Script" "$*"
}

# Determine direction
case "$1" in
    --increase) DIR="up" ;;
    --decrease) DIR="down" ;;
    *) notify "Usage: $0 --increase|--decrease"; exit 1 ;;
esac

# Get active window address
ADDR=$(hyprctl activewindow -j | jq -r '.address')

if [[ -z "$ADDR" || "$ADDR" == "null" ]]; then
    notify "No active window found"
    log "Failed to get active window address"
    exit 1
fi

# Get current opacity from the alpha prop (persistent)
CURRENT_OPACITY=$(hyprctl getprop "address:$ADDR" alpha 2>/dev/null | awk '/alpha/ {print $2}')

# If no current alpha set, default to 1.0
if [[ -z "$CURRENT_OPACITY" ]]; then
    CURRENT_OPACITY=1.0
fi

log "Window: $ADDR, Direction: $DIR, Current opacity: $CURRENT_OPACITY"

# Calculate new opacity
if [[ "$DIR" == "up" ]]; then
    NEW_OPACITY=$(echo "$CURRENT_OPACITY + $OPACITY_STEP" | bc -l)
    CMP=$(echo "$NEW_OPACITY > $MAX_OPACITY" | bc)
    [[ "$CMP" -eq 1 ]] && NEW_OPACITY=$MAX_OPACITY
else
    NEW_OPACITY=$(echo "$CURRENT_OPACITY - $OPACITY_STEP" | bc -l)
    CMP=$(echo "$NEW_OPACITY < $MIN_OPACITY" | bc)
    [[ "$CMP" -eq 1 ]] && NEW_OPACITY=$MIN_OPACITY
fi

# Format opacity to one decimal place
NEW_OPACITY=$(printf "%.1f" "$NEW_OPACITY")

# Apply new persistent alpha value
hyprctl dispatch setprop "address:$ADDR" alpha "$NEW_OPACITY"

if [[ $? -eq 0 ]]; then
    log "Set opacity for $ADDR to $NEW_OPACITY"
    notify "Set opacity to $NEW_OPACITY"
else
    log "Failed to set opacity for $ADDR"
    notify "Failed to set opacity"
fi

