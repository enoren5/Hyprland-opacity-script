#!/usr/bin/env bash

# A script to increase or decrease the active window opacity in Hyprland

LOG_FILE="/tmp/hypr_opacity_script.log"

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Script started"

OPACITY_STEP=0.1
MIN_OPACITY=0.0
MAX_OPACITY=1.0

# Get the direction from argument
DIRECTION="$1"
log_message "Direction argument: $DIRECTION"

if [[ "$DIRECTION" != "--increase" && "$DIRECTION" != "--decrease" ]]; then
  log_message "Invalid direction argument. Usage: $0 --increase|--decrease"
  echo "Usage: $0 --increase|--decrease" >> "$LOG_FILE"
  exit 1
fi

# Get current opacity value
CURRENT_OPACITY=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')

# Fallback if jq or value missing
if [[ -z "$CURRENT_OPACITY" || "$CURRENT_OPACITY" == "null" ]]; then
  log_message "Failed to get current opacity. Output: $(hyprctl getoption decoration:active_opacity -j)"
  echo "Failed to get current opacity." >> "$LOG_FILE"
  exit 1
fi
log_message "Current opacity: $CURRENT_OPACITY"

# Adjust opacity
if [[ "$DIRECTION" == "--increase" ]]; then
  NEW_OPACITY=$(echo "$CURRENT_OPACITY + $OPACITY_STEP" | bc)
  COMPARE=$(echo "$NEW_OPACITY > $MAX_OPACITY" | bc)
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_OPACITY=$MAX_OPACITY
  fi
  log_message "Increasing opacity. New opacity (before clamp): $NEW_OPACITY"
else
  NEW_OPACITY=$(echo "$CURRENT_OPACITY - $OPACITY_STEP" | bc)
  COMPARE=$(echo "$NEW_OPACITY < $MIN_OPACITY" | bc)
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_OPACITY=$MIN_OPACITY
  fi
  log_message "Decreasing opacity. New opacity (before clamp): $NEW_OPACITY"
fi

# Format new opacity to avoid scientific notation and limit decimal places if needed
NEW_OPACITY=$(printf "%.10f" "$NEW_OPACITY" | sed '/\.0*$/s///') # Basic formatting, adjust precision as needed
log_message "New opacity (after clamp and format): $NEW_OPACITY"


# Set new opacity
hyprctl keyword decoration:active_opacity "$NEW_OPACITY"
if [ $? -eq 0 ]; then
  log_message "Successfully set opacity to $NEW_OPACITY"
else
  log_message "Failed to set opacity to $NEW_OPACITY. hyprctl exit code: $?"
fi

log_message "Script finished"