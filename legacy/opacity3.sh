#!/usr/bin/env bash

# A script to increase or decrease the active window opacity in Hyprland
# This version uses hyprctl activewindow and setprop

LOG_FILE="/tmp/hypr_opacity_script_v2.log"

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Script started (v2)"

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

# Get the address of the active window
ACTIVE_WINDOW_ADDRESS=$(hyprctl activewindow -j | jq -r '.address')

# Check if we got a valid address
if [[ -z "$ACTIVE_WINDOW_ADDRESS" || "$ACTIVE_WINDOW_ADDRESS" == "null" ]]; then
  log_message "Could not get active window address."
  echo "Could not get active window address." >> "$LOG_FILE"
  exit 1
fi
log_message "Active window address: $ACTIVE_WINDOW_ADDRESS"

# Get current opacity for the active window using getprop
# Note: setprop opacity is a multiplier on top of decoration:active_opacity
# We'll retrieve the current 'opacity' property value if it exists, otherwise assume 1 (fully opaque multiplier)
CURRENT_MULTIPLIER=$(hyprctl getprop address:"$ACTIVE_WINDOW_ADDRESS" opacity -j | jq -r '.float')

# Fallback if getprop fails or value missing, assume current multiplier is 1.0
if [[ -z "$CURRENT_MULTIPLIER" || "$CURRENT_MULTIPLIER" == "null" ]]; then
  CURRENT_MULTIPLIER=1.0
  log_message "Failed to get current window opacity multiplier. Assuming 1.0. Output: $(hyprctl getprop address:"$ACTIVE_WINDOW_ADDRESS" opacity -j)"
else
  log_message "Current window opacity multiplier: $CURRENT_MULTIPLIER"
fi


# Adjust opacity multiplier
if [[ "$DIRECTION" == "--increase" ]]; then
  # Increasing opacity means increasing the multiplier towards 1.0
  NEW_MULTIPLIER=$(echo "$CURRENT_MULTIPLIER + $OPACITY_STEP" | bc)
  COMPARE=$(echo "$NEW_MULTIPLIER > $MAX_OPACITY" | bc)
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_MULTIPLIER=$MAX_OPACITY
  fi
  log_message "Increasing multiplier. New multiplier (before clamp): $NEW_MULTIPLIER"
else
  # Decreasing opacity means decreasing the multiplier towards 0.0
  NEW_MULTIPLIER=$(echo "$CURRENT_MULTIPLIER - $OPACITY_STEP" | bc)
  COMPARE=$(echo "$NEW_MULTIPLIER < $MIN_OPACITY" | bc)
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_MULTIPLIER=$MIN_OPACITY
  fi
  log_message "Decreasing multiplier. New multiplier (before clamp): $NEW_MULTIPLIER"
fi

# Format new multiplier
NEW_MULTIPLIER=$(printf "%.10f" "$NEW_MULTIPLIER" | sed '/\.0*$/s///') # Basic formatting

log_message "New window opacity multiplier (after clamp and format): $NEW_MULTIPLIER"

# Set new opacity multiplier for the active window
hyprctl setprop address:"$ACTIVE_WINDOW_ADDRESS" opacity "$NEW_MULTIPLIER"
if [ $? -eq 0 ]; then
  log_message "Successfully set opacity multiplier to $NEW_MULTIPLIER for $ACTIVE_WINDOW_ADDRESS"
else
  log_message "Failed to set opacity multiplier to $NEW_MULTIPLIER for $ACTIVE_WINDOW_ADDRESS. hyprctl exit code: $?"
fi

log_message "Script finished (v3)"