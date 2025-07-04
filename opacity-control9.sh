#!/usr/bin/env bash

# File: opacity-control.sh

NOTIFY_TITLE="Hyprland Opacity"
LOG_FILE="/tmp/hypr_opacity_memory.log"
MEMORY_FILE="/tmp/hypr_alpha_memory.json"

JQ=$(which jq)
HYPRCTL=$(which hyprctl)

OPACITY_STEP=0.05
MIN_OPACITY=0.1
MAX_OPACITY=1.0
DEFAULT_ALPHA=1.0

mkdir -p "$(dirname "$MEMORY_FILE")"
touch "$MEMORY_FILE"
[[ ! -s $MEMORY_FILE ]] && echo "{}" > "$MEMORY_FILE"

DIRECTION="$1"

# Get the address of the active window
ADDR=$($HYPRCTL activewindow -j | $JQ -r '.address')
[[ -z "$ADDR" || "$ADDR" == "null" ]] && notify-send "$NOTIFY_TITLE" "No active window found" && exit 1

# Load current or default alpha
CURRENT_ALPHA=$(cat "$MEMORY_FILE" | $JQ -r --arg addr "$ADDR" '.[$addr] // 1.0')

# Decide new alpha
case "$DIRECTION" in
    --increase)
        NEW_ALPHA=$(echo "$CURRENT_ALPHA + $OPACITY_STEP" | bc)
        (( $(echo "$NEW_ALPHA > $MAX_OPACITY" | bc -l) )) && NEW_ALPHA=$MAX_OPACITY
        ;;
    --decrease)
        NEW_ALPHA=$(echo "$CURRENT_ALPHA - $OPACITY_STEP" | bc)
        (( $(echo "$NEW_ALPHA < $MIN_OPACITY" | bc -l) )) && NEW_ALPHA=$MIN_OPACITY
        ;;
    --reset)
        NEW_ALPHA=$DEFAULT_ALPHA
        ;;
    *)
        notify-send "$NOTIFY_TITLE" "Usage: $0 --increase | --decrease | --reset"
        exit 1
        ;;
esac

# Apply alpha to all states
for PROP in alpha alphainactive alphafullscreen alphaoverride; do
    $HYPRCTL dispatch setprop "address:$ADDR" "$PROP" "$NEW_ALPHA"
done

# Save new alpha (even if reset) to memory file
TMP=$(mktemp)
cat "$MEMORY_FILE" | $JQ --arg addr "$ADDR" --argjson val "$NEW_ALPHA" '. + {($addr): $val}' > "$TMP" && mv "$TMP" "$MEMORY_FILE"

# Notify user
# notify-send "$NOTIFY_TITLE" "Window $ADDR\nAlpha set to: $NEW_ALPHA"

