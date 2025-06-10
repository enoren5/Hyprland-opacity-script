#!/bin/bash

# Simple opacity control script for Hyprland
# Usage: ./opacity.sh --increase or ./opacity.sh --decrease

# Config
STEP=0.1
MIN_OPACITY=0.1
MAX_OPACITY=1.0
DEFAULT_OPACITY=1.0

# Required tools (assumes they're in PATH)
command -v hyprctl >/dev/null || { echo "hyprctl not found"; exit 1; }
command -v jq >/dev/null || { echo "jq not found"; exit 1; }

# Get currently focused window
WIN_ADDR=$(hyprctl activewindow -j | jq -r '.address')
[ -z "$WIN_ADDR" ] || [ "$WIN_ADDR" == "null" ] && { echo "No active window"; exit 1; }

# Get current opacity (if set, else assume 1.0)
CURRENT_OPACITY=$(hyprctl getprop "address:$WIN_ADDR" alphaoverride 2>/dev/null | awk '{print $2}')
[ -z "$CURRENT_OPACITY" ] && CURRENT_OPACITY=$DEFAULT_OPACITY

# Adjust opacity
if [[ "$1" == "--increase" ]]; then
    NEW_OPACITY=$(echo "$CURRENT_OPACITY + $STEP" | bc -l)
elif [[ "$1" == "--decrease" ]]; then
    NEW_OPACITY=$(echo "$CURRENT_OPACITY - $STEP" | bc -l)
else
    echo "Usage: $0 --increase|--decrease"
    exit 1
fi

# Clamp opacity between MIN and MAX
NEW_OPACITY=$(echo "$NEW_OPACITY" | awk -v min="$MIN_OPACITY" -v max="$MAX_OPACITY" '{
    if ($1 < min) $1 = min;
    if ($1 > max) $1 = max;
    printf "%.2f", $1;
}')

# Set new opacity
hyprctl dispatch setprop "address:$WIN_ADDR" alphaoverride "$NEW_OPACITY"

