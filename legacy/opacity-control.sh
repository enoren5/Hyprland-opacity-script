
#!/usr/bin/env bash

# Simpler script to adjust opacity (alpha) per-window in Hyprland
# Supports --increase and --decrease

LOG_FILE="/tmp/hypr_opacity.log"
STEP=0.1
MIN=0.1
MAX=1.0
CACHE="/tmp/hypr_opacity_cache"

mkdir -p "$(dirname "$CACHE")"

log() {
  echo "$(date '+%F %T') - $*" >> "$LOG_FILE"
}

notify() {
  notify-send "Opacity Script" "$*"
}

# Get active window address
ADDRESS=$(hyprctl activewindow -j | jq -r '.address')
[ -z "$ADDRESS" ] && log "No active window found" && exit 1

# Load current opacity from cache, or default to 1.0
CURRENT=$(grep "$ADDRESS" "$CACHE" 2>/dev/null | cut -d' ' -f2)
[ -z "$CURRENT" ] && CURRENT="1.0"

case "$1" in
  --increase)
    NEW=$(echo "$CURRENT + $STEP" | bc)
    ;;
  --decrease)
    NEW=$(echo "$CURRENT - $STEP" | bc)
    ;;
  *)
    notify "Usage: $0 --increase|--decrease"
    exit 1
    ;;
esac

# Clamp within MIN and MAX
if (( $(echo "$NEW > $MAX" | bc -l) )); then NEW=$MAX; fi
if (( $(echo "$NEW < $MIN" | bc -l) )); then NEW=$MIN; fi

# Apply new opacity
hyprctl dispatch setprop "address:$ADDRESS" alpha "$NEW"
# hyprctl dispatch setprop address:$ADDR alphaoverride $NEW_OPACITY

RES=$?

if [ $RES -eq 0 ]; then
  # Update cache
  grep -v "$ADDRESS" "$CACHE" > "$CACHE.tmp"
  echo "$ADDRESS $NEW" >> "$CACHE.tmp"
  mv "$CACHE.tmp" "$CACHE"

  notify "Window opacity: $NEW"
  log "Set $ADDRESS alpha to $NEW"
else
  notify "Failed to set opacity"
  log "Failed to set opacity for $ADDRESS"
fi
