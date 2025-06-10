#!/usr/bin/env bash

# A script to increase or decrease the active window opacity in Hyprland
# This version gets the global active_opacity and sets it as a multiplier for the active window.
# If you are using Hyprland 0.48.1 or newer, check your 'windowrule' entries for conflicts.

LOG_FILE="/tmp/hypr_opacity_script_v7_revisited.log"
# Replace with the actual paths found using 'which jq', 'which hyprctl', and 'which bc'
JQ_PATH="/run/current-system/sw/bin/jq" # <-- Update this path if needed
HYPRCTL_PATH="/run/current-system/sw/bin/hyprctl" # <-- Update this path if needed
BC_PATH="/run/current-system/sw/bin/bc" # <-- Update this path if needed

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Script started (v7 revisited)"

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

# Get the current GLOBAL active opacity using getoption
GETOPTION_OUTPUT=$(${HYPRCTL_PATH} getoption decoration:active_opacity -j 2>&1) # Capture stderr too
log_message "hyprctl getoption decoration:active_opacity output: $GETOPTION_OUTPUT"

# Parse the global opacity value
CURRENT_GLOBAL_OPACITY=$(echo "$GETOPTION_OUTPUT" | ${JQ_PATH} -r '.float' 2>/dev/null)

# Fallback if jq failed or parsed value is null/empty
if [[ -z "$CURRENT_GLOBAL_OPACITY" || "$CURRENT_GLOBAL_OPACITY" == "null" ]]; then
  log_message "Failed to parse global active opacity from getoption output: '$GETOPTION_OUTPUT'. Assuming 1.0."
  CURRENT_GLOBAL_OPACITY=1.0
else
  log_message "Current global active opacity: $CURRENT_GLOBAL_OPACITY"
fi

# Use the CURRENT_GLOBAL_OPACITY as the base for calculation
# The setprop opacity acts as a multiplier on this base.
# By setting the multiplier to the desired final opacity, we achieve the effect.
CURRENT_WINDOW_OPACITY_AS_BASE="$CURRENT_GLOBAL_OPACITY"
log_message "Using global opacity ($CURRENT_WINDOW_OPACITY_AS_BASE) as base for window opacity calculation."

# Adjust desired opacity for the window
if [[ "$DIRECTION" == "--increase" ]]; then
  # Increasing opacity means increasing the value towards 1.0
  NEW_DESIRED_OPACITY=$(echo "$CURRENT_WINDOW_OPACITY_AS_BASE + $OPACITY_STEP" | ${BC_PATH})
  COMPARE=$(echo "$NEW_DESIRED_OPACITY > $MAX_OPACITY" | ${BC_PATH})
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_DESIRED_OPACITY=$MAX_OPACITY
  fi
  log_message "Increasing desired opacity. New desired opacity (before clamp): $NEW_DESIRED_OPACITY"
else
  # Decreasing opacity means decreasing the value towards 0.0
  NEW_DESIRED_OPACITY=$(echo "$CURRENT_WINDOW_OPACITY_AS_BASE - $OPACITY_STEP" | ${BC_PATH})
  COMPARE=$(echo "$NEW_DESIRED_OPACITY < $MIN_OPACITY" | ${BC_PATH})
  if [[ "$COMPARE" -eq 1 ]]; then
    NEW_DESIRED_OPACITY=$MIN_OPACITY
  fi
  log_message "Decreasing desired opacity. New desired opacity (before clamp): $NEW_DESIRED_OPACITY"
fi

# Format new desired opacity
# Use printf with a high precision to avoid scientific notation, then remove trailing zeros and decimal if integer
NEW_DESIRED_OPACITY=$(printf "%.10f" "$NEW_DESIRED_OPACITY" | sed 's/\.\?0*$//')
# If the result is just a decimal point, remove it
NEW_DESIRED_OPACITY=$(echo "$NEW_DESIRED_OPACITY" | sed 's/^\.$//')
# If the result is empty (e.g., from 0.0), set it to 0
if [[ -z "$NEW_DESIRED_OPACITY" ]]; then
  NEW_DESIRED_OPACITY="0"
fi

log_message "Calculated new desired window opacity (after clamp and format): $NEW_DESIRED_OPACITY"

# Set the calculated desired opacity as the multiplier for the active window
${HYPRCTL_PATH} dispatch setprop address:"$ACTIVE_WINDOW_ADDRESS" alphaoverride "$NEW_DESIRED_OPACITY"
if [ $? -eq 0 ]; then
  log_message "Successfully set opacity multiplier to $NEW_DESIRED_OPACITY for $ACTIVE_WINDOW_ADDRESS"
else
  log_message "Failed to set opacity multiplier to $NEW_DESIRED_OPACITY for $ACTIVE_WINDOW_ADDRESS. hyprctl dispatch setprop exit code: $?"
  log_message "hyprctl dispatch setprop final output: $(${HYPRCTL_PATH} dispatch setprop address:"$ACTIVE_WINDOW_ADDRESS" alphaoverride "$NEW_DESIRED_OPACITY" 2>&1)"
fi

log_message "Script finished (v7 revisited)"
