#!/usr/bin/env bash
#!/usr/bin/env bash

# Working script for Hyprland 0.49.0 using 'alpha' instead of 'alphaoverride'

LOGFILE="/tmp/hypr_opacity.log"
echo "$(date) $0 $@" >> "$LOGFILE"

STEP=0.1
MIN=0.1
MAX=1.0

command -v jq >/dev/null || exit 1
command -v bc >/dev/null || exit 1

WIN_ADDR=$(hyprctl activewindow -j | jq -r '.address')
[ -z "$WIN_ADDR" ] && exit 1

# Get current alpha multiplier
CUR=$(hyprctl getprop "address:$WIN_ADDR" alpha | awk '{print $2}')
[ -z "$CUR" ] && CUR="1.0"

if [[ "$1" == "--increase" ]]; then
    NEW=$(echo "$CUR + $STEP" | bc -l)
elif [[ "$1" == "--decrease" ]]; then
    NEW=$(echo "$CUR - $STEP" | bc -l)
else
    echo "Usage: $0 --increase|--decrease"
    exit 1
fi

NEW=$(echo "$NEW" | awk -v min="$MIN" -v max="$MAX" '{
    if ($1 < min) $1 = min;
    if ($1 > max) $1 = max;
    printf "%.2f", $1;
}')

notify-send "Opacity Script" "Triggered: $0 $@"

hyprctl dispatch setprop "address:$WIN_ADDR" alpha "$NEW"

