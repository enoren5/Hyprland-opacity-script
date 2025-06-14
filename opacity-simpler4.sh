#!/usr/bin/env bash

LOGFILE="/tmp/hypr_opacity.log"
STEP=0.1
MIN=0.1
MAX=1.0

# notify-send "Opacity Script" "Triggered: $0 $@" >> "$LOGFILE"
echo "$(date) Triggered: $0 $@" >> "$LOGFILE"

# Get active window address
ADDR=$(hyprctl activewindow -j | jq -r '.address')
if [[ -z "$ADDR" || "$ADDR" == "null" ]]; then
  notify-send "Opacity Script Error" "No active window."
  exit 1
fi

# Get current alpha
CURRENT_ALPHA=$(hyprctl getprop "address:$ADDR" -j | jq -r '.[] | select(.name=="alpha") | .value')
if [[ -z "$CURRENT_ALPHA" || "$CURRENT_ALPHA" == "null" ]]; then
  CURRENT_ALPHA=1.0
fi

# Calculate new value
if [[ "$1" == "--decrease" ]]; then
  NEW_ALPHA=$(echo "$CURRENT_ALPHA - $STEP" | bc)
elif [[ "$1" == "--increase" ]]; then
  NEW_ALPHA=$(echo "$CURRENT_ALPHA + $STEP" | bc)
else
  notify-send "Opacity Script Error" "Invalid argument. Use --increase or --decrease."
  exit 1
fi

# Clamp to range
CMP_LOW=$(echo "$NEW_ALPHA < $MIN" | bc)
CMP_HIGH=$(echo "$NEW_ALPHA > $MAX" | bc)
if [[ "$CMP_LOW" -eq 1 ]]; then
  NEW_ALPHA=$MIN
elif [[ "$CMP_HIGH" -eq 1 ]]; then
  NEW_ALPHA=$MAX
fi

# Set new alpha
hyprctl dispatch setprop "address:$ADDR" alpha "$NEW_ALPHA"
echo "$(date) New alpha: $NEW_ALPHA" >> "$LOGFILE"

