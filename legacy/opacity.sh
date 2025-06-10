#!/usr/bin/env bash

# A script to increase or decrease the active window opacity in Hyprland

OPACITY_STEP=0.1
MIN_OPACITY=0.0
MAX_OPACITY=1.0

# Get the direction from argument
DIRECTION="$1"

if [[ "$DIRECTION" != "--increase" && "$DIRECTION" != "--decrease" ]]; then
  echo "Usage: $0 --increase|--decrease"
  exit 1
fi

# Get current opacity value
CURRENT_OPACITY=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')

# Fallback if jq or value missing
if [[ -z "$CURRENT_OPACITY" || "$CURRENT_OPACITY" == "null" ]]; then
  echo "Failed to get current opacity."
  exit 1
fi

# Adjust opacity
if [[ "$DIRECTION" == "--increase" ]]; then
  NEW_OPACITY=$(echo "$CURRENT_OPACITY + $OPACITY_STEP" | bc)
  COMPARE=$(echo "$NEW_OPACITY > $MAX_OPACITY" | bc)
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_OPACITY=$MAX_OPACITY
  fi
else
  NEW_OPACITY=$(echo "$CURRENT_OPACITY - $OPACITY_STEP" | bc)
  COMPARE=$(echo "$NEW_OPACITY < $MIN_OPACITY" | bc)
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_OPACITY=$MIN_OPACITY
  fi
fi

# Set new opacity
hyprctl keyword decoration:active_opacity "$NEW_OPACITY"
