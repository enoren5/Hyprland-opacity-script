#!/usr/bin/env bash

# A script to increase or decrease the active window opacity in Hyprland
# This version uses hyprctl activewindow and dispatch setprop, with full paths, delay, and improved error handling.

LOG_FILE="/tmp/hypr_opacity_script_v4.log"
# Replace with the actual paths found using 'which jq', 'which hyprctl', and 'which bc'
JQ_PATH="/run/current-system/sw/bin/jq" # <-- Update this path if needed
HYPRCTL_PATH="/run/current-system/sw/bin/hyprctl" # <-- Update this path if needed
BC_PATH="/run/current-system/sw/bin/bc" # <-- Update this path if needed

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Script started (v4)"

# Add a small delay to ensure Hyprland is ready
sleep 0.05 # Adjust delay if necessary

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
ACTIVE_WINDOW_ADDRESS=$(${HYPRCTL_PATH} activewindow -j | ${JQ_PATH} -r '.address')

# Check if we got a valid address
if [[ -z "$ACTIVE_WINDOW_ADDRESS" || "$ACTIVE_WINDOW_ADDRESS" == "null" ]]; then
  log_message "Could not get active window address. hyprctl output: $(${HYPRCTL_PATH} activewindow -j)"
  echo "Could not get active window address." >> "$LOG_FILE"
  exit 1
fi
log_message "Active window address: $ACTIVE_WINDOW_ADDRESS"

# Get current opacity multiplier for the active window using getprop
# We'll try to get the 'opacity' property. If it doesn't exist or fails, assume 1.0 (fully opaque multiplier).
GETPROP_OUTPUT=$(${HYPRCTL_PATH} getprop address:"$ACTIVE_WINDOW_ADDRESS" opacity -j 2>&1) # Capture stderr too
log_message "hyprctl getprop output: $GETPROP_OUTPUT"

# Check if getprop returned a valid float
CURRENT_MULTIPLIER=$(echo "$GETPROP_OUTPUT" | ${JQ_PATH} -r '.float' 2>/dev/null) # Suppress jq errors here

# Fallback if jq failed, output was null, or value missing, assume current multiplier is 1.0
if [[ -z "$CURRENT_MULTIPLIER" || "$CURRENT_MULTIPLIER" == "null" ]]; then
  CURRENT_MULTIPLIER=1.0
  log_message "Failed to get current window opacity multiplier via jq or value is null/empty. Assuming 1.0."
else
  log_message "Current window opacity multiplier: $CURRENT_MULTIPLIER"
fi


# Adjust opacity multiplier
if [[ "$DIRECTION" == "--increase" ]]; then
  # Increasing opacity means increasing the multiplier towards 1.0
  NEW_MULTIPLIER=$(echo "$CURRENT_MULTIPLIER + $OPACITY_STEP" | ${BC_PATH})
  COMPARE=$(echo "$NEW_MULTIPLIER > $MAX_OPACITY" | ${BC_PATH})
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_MULTIPLIER=$MAX_OPACITY
  fi
  log_message "Increasing multiplier. New multiplier (before clamp): $NEW_MULTIPLIER"
else
  # Decreasing opacity means decreasing the multiplier towards 0.0
  NEW_MULTIPLIER=$(echo "$CURRENT_MULTIPLIER - $OPACITY_STEP" | ${BC_PATH})
  COMPARE=$(echo "$NEW_MULTIPLIER < $MIN_OPACITY" | ${BC_PATH})
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_MULTIPLIER=$MIN_OPACITY
  fi
  log_message "Decreasing multiplier. New multiplier (before clamp): $NEW_MULTIPLIER"
fi

# Format new multiplier
# Use printf with a high precision to avoid scientific notation, then remove trailing zeros and decimal if integer
NEW_MULTIPLIER=$(printf "%.10f" "$NEW_MULTIPLIER" | sed 's/\.?0*$/분이/') # Basic formatting

log_message "New window opacity multiplier (after clamp and format): $NEW_MULTIPLIER"

# Set new opacity multiplier for the active window using dispatch setprop
${HYPRCTL_PATH} dispatch setprop address:"$ACTIVE_WINDOW_ADDRESS" opacity "$NEW_MULTIPLIER"
if [ $? -eq 0 ]; then
  log_message "Successfully set opacity multiplier to $NEW_MULTIPLIER for $ACTIVE_WINDOW_ADDRESS"
else
  log_message "Failed to set opacity multiplier to $NEW_MULTIPLIER for $ACTIVE_WINDOW_ADDRESS. hyprctl dispatch setprop exit code: $?"
fi

log_message "Script finished (v4)"
