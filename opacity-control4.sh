#!/usr/bin/env bash

LOG_FILE="/tmp/hypr_opacity.log"
STEP=0.1
MIN_OPACITY=0.1
MAX_OPACITY=1.0
MODE="alpha"  # Default is persistent
STATE_DIR="/tmp/hypr_opacity_state"

mkdir -p "$STATE_DIR"

# Parse flags
for arg in "$@"; do
    case $arg in
        --transient)
            MODE="alphaoverride"
            ;;
        --increase|--decrease)
            ACTION=$arg
            ;;
    esac
done

# Exit if required
if [ -z "$ACTION" ]; then
    notify-send "Opacity Script" "Usage: $0 [--transient] --increase|--decrease"
    exit 1
fi

ADDR=$(hyprctl activewindow -j | jq -r '.address')
STATE_FILE="$STATE_DIR/$ADDR"

# Load current opacity
if [[ -f "$STATE_FILE" ]]; then
    OPACITY=$(cat "$STATE_FILE")
else
    OPACITY=$MAX_OPACITY
fi

# Calculate new opacity
if [[ "$ACTION" == "--increase" ]]; then
    OPACITY=$(awk -v val="$OPACITY" -v step="$STEP" -v max="$MAX_OPACITY" 'BEGIN { o = val + step; if (o > max) o = max; printf "%.1f", o }')
else
    OPACITY=$(awk -v val="$OPACITY" -v step="$STEP" -v min="$MIN_OPACITY" 'BEGIN { o = val - step; if (o < min) o = min; printf "%.1f", o }')
fi

# Set property
hyprctl dispatch setprop "address:$ADDR" "$MODE" "$OPACITY"

# Save only if persistent
if [[ "$MODE" == "alpha" ]]; then
    echo "$OPACITY" > "$STATE_FILE"
fi

# Notify and log
notify-send "Window Opacity ($MODE)" "$OPACITY"
echo "$(date) | $MODE | $ACTION | $ADDR | $OPACITY" >> "$LOG_FILE"

