#!/usr/bin/env bash

# Hyprland Window Opacity Adjuster
# Requires: hyprctl, jq, bc, notify-send
# Adjusts persistent window opacity using `alpha` per window, and re-applies it on focus change.

LOG="/tmp/hypr_opacity_persist.log"
OPACITY_STEP=0.1
MIN_OPACITY=0.1
MAX_OPACITY=1.0
PERSISTENT_OPACITY_DIR="$HOME/.config/hypr/window_opacities" # Directory to store per-window opacities

# Ensure the persistent opacity directory exists
mkdir -p "$PERSISTENT_OPACITY_DIR"

# Logging utility
log() {
    echo "$(date '+%F %T') - $*" >> "$LOG"
}

# Send notification
notify() {
    notify-send "Opacity Script" "$*"
}

# Function to get current opacity from the alpha prop (persistent)
get_current_alpha() {
    local addr="$1"
    # Try to get the alpha property set by hyprctl dispatch setprop
    local current_alpha=$(hyprctl getprop "address:$addr" alpha 2>/dev/null | awk '/alpha/ {print $2}')
    if [[ -z "$current_alpha" ]]; then
        echo "1.0" # Default to 1.0 if no alpha property is set
    else
        echo "$current_alpha"
    fi
}

# Function to apply opacity to a window
apply_opacity() {
    local addr="$1"
    local opacity_value="$2"
    hyprctl dispatch setprop "address:$addr" alpha "$opacity_value"
    if [[ $? -eq 0 ]]; then
        log "Applied opacity $opacity_value to $addr"
    else
        log "Failed to apply opacity $opacity_value to $addr"
    fi
}

# --- Main script logic ---

# If no arguments, it's likely being called by the Hyprland event listener
if [[ -z "$1" ]]; then
    # This part handles re-applying opacity when window focus changes
    # It will be called by Hyprland's event listener (see Hyprland config below)
    while IFS= read -r line; do
        if [[ "$line" =~ ^activewindow>>(.+)$ ]]; then
            ADDR="${BASH_REMATCH[1]}"
            if [[ -z "$ADDR" || "$ADDR" == "null" ]]; then
                log "No active window found from event"
                continue
            fi
            
            # Get the persistently stored opacity for this window
            STORED_OPACITY=$(get_current_alpha "$ADDR")
            log "Window focused: $ADDR, Stored opacity: $STORED_OPACITY"
            apply_opacity "$ADDR" "$STORED_OPACITY"
        fi
    done < <(socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock)
    exit 0 # Exit after setting up the event listener
fi

# Determine direction for opacity adjustment
case "$1" in
    --increase) DIR="up" ;;
    --decrease) DIR="down" ;;
    *) notify "Usage: $0 --increase|--decrease"; exit 1 ;;
esac

# Get active window address for adjustment
ADDR=$(hyprctl activewindow -j | jq -r '.address')

if [[ -z "$ADDR" || "$ADDR" == "null" ]]; then
    notify "No active window found to adjust"
    log "Failed to get active window address for adjustment"
    exit 1
fi

# Get current opacity for calculation
CURRENT_OPACITY=$(get_current_alpha "$ADDR")

log "Window: $ADDR, Direction: $DIR, Current opacity: $CURRENT_OPACITY"

# Calculate new opacity
if [[ "$DIR" == "up" ]]; then
    NEW_OPACITY=$(echo "$CURRENT_OPACITY + $OPACITY_STEP" | bc -l)
    CMP=$(echo "$NEW_OPACITY > $MAX_OPACITY" | bc)
    [[ "$CMP" -eq 1 ]] && NEW_OPACITY=$MAX_OPACITY
else
    NEW_OPACITY=$(echo "$CURRENT_OPACITY - $OPACITY_STEP" | bc -l)
    CMP=$(echo "$NEW_OPACITY < $MIN_OPACITY" | bc)
    [[ "$CMP" -eq 1 ]] && NEW_OPACITY=$MIN_OPACITY
fi

# Format opacity to one decimal place
NEW_OPACITY=$(printf "%.1f" "$NEW_OPACITY")

# Apply new persistent alpha value
apply_opacity "$ADDR" "$NEW_OPACITY"

if [[ $? -eq 0 ]]; then
    log "Set opacity for $ADDR to $NEW_OPACITY"
    notify "Set opacity to $NEW_OPACITY"
else
    log "Failed to set opacity for $ADDR"
    notify "Failed to set opacity"
fi
