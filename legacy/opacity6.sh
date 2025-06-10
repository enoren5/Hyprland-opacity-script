#!/usr/bin/env bash

# A script to increase or decrease the active window opacity in Hyprland
# This version attempts an explicit first set to 1.0 if the opacity property is not found.

LOG_FILE="/tmp/hypr_opacity_script_v6.log"
# Replace with the actual paths found using 'which jq', 'which hyprctl', and 'which bc'
JQ_PATH="/run/current-system/sw/bin/jq" # <-- Update this path if needed
HYPRCTL_PATH="/run/current-system/sw/bin/hyprctl" # <-- Update this path if needed
BC_PATH="/run/current-system/sw/bin/bc" # <-- Update this path if needed

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Script started (v6)"

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

# --- Get Current Opacity Multiplier ---
# We'll try to get the 'opacity' property. If it doesn't exist or fails, assume 1.0 (fully opaque multiplier).
GETPROP_OUTPUT=$(${HYPRCTL_PATH} getprop address:"$ACTIVE_WINDOW_ADDRESS" opacity -j 2>&1) # Capture stderr too
log_message "hyprctl getprop output: $GETPROP_OUTPUT"

# Check if the output contains "Prop not found"
if echo "$GETPROP_OUTPUT" | grep -q "Prop not found"; then
  log_message "Opacity property not found for this window. Attempting initial set to 1.0."

  # Attempt to set the opacity to 1.0 explicitly to create the property
  ${HYPRCTL_PATH} dispatch setprop address:"$ACTIVE_WINDOW_ADDRESS" opacity 1.0
  if [ $? -eq 0 ]; then
    log_message "Successfully performed initial set to 1.0."
    CURRENT_MULTIPLIER=1.0 # After successful initial set, current is 1.0
  else
    log_message "Initial set to 1.0 failed. Cannot proceed. hyprctl dispatch setprop exit code: $?"
    log_message "hyprctl dispatch setprop 1.0 output: $(${HYPRCTL_PATH} dispatch setprop address:"$ACTIVE_WINDOW_ADDRESS" opacity 1.0 2>&1)"
    echo "Failed to initialize opacity property." >> "$LOG_FILE"
    exit 1 # Exit if we can't even set it to 1.0
  fi
else
  # Property found, attempt to parse the float value using jq
  PARSED_MULTIPLIER=$(echo "$GETPROP_OUTPUT" | ${JQ_PATH} -r '.float' 2>/dev/null)

  # Fallback if jq failed or parsed value is null/empty
  if [[ -z "$PARSED_MULTIPLIER" || "$PARSED_MULTIPLIER" == "null" ]]; then
    log_message "Failed to parse opacity multiplier from getprop output: '$GETPROP_OUTPUT'. Assuming 1.0."
    CURRENT_MULTIPLIER=1.0
  else
    CURRENT_MULTIPLIER="$PARSED_MULTIPLIER"
    log_message "Current window opacity multiplier: $CURRENT_MULTIPLIER"
  fi
fi
# --- End Get Current Opacity Multiplier ---


# Adjust opacity multiplier based on CURRENT_MULTIPLIER
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
NEW_MULTIPLIER=$(printf "%.10f" "$NEW_MULTIPLIER" | sed 's/\.\?0*$//')
# If the result is just a decimal point, remove it
NEW_MULTIPLIER=$(echo "$NEW_MULTIPLIER" | sed 's/^\.$//')
# If the result is empty (e.g., from 0.0), set it to 0
if [[ -z "$NEW_MULTIPLIER" ]]; then
  NEW_MULTIPLIER="0"
fi


log_message "Calculated new window opacity multiplier (after clamp and format): $NEW_MULTIPLIER"

# Set the final new opacity multiplier for the active window
${HYPRCTL_PATH} dispatch setprop address:"$ACTIVE_WINDOW_ADDRESS" opacity "$NEW_MULTIPPLIER"
if [ $? -eq 0 ]; then
  log_message "Successfully set opacity multiplier to $NEW_MULTIPLIER for $ACTIVE_WINDOW_ADDRESS"
else
  log_message "Failed to set opacity multiplier to $NEW_MULTIPPLIER for $ACTIVE_WINDOW_ADDRESS. hyprctl dispatch setprop exit code: $?"
  log_message "hyprctl dispatch setprop final output: $(${HYPRCTL_PATH} dispatch setprop address:"$ACTIVE_WINDOW_ADDRESS" opacity "$NEW_MULTIPPLIER" 2>&1)"
fi

log_message "Script finished (v6)"
