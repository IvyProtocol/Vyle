#!/usr/bin/env bash
# waybar_battery_combined.sh
# Usage:
#   no-args -> outputs JSON for Waybar
#   toggle  -> flips click-mode (show time beside icon)

TOGGLE="/tmp/waybar_battery_show_alt_$USER"
HISTORY="/tmp/waybar_battery_hist-$USER"
HIST_N=3

BAT0="/sys/class/power_supply/BAT0"
BAT1="/sys/class/power_supply/BAT1"

# Automatically detect AC adapter
AC=""
for path in /sys/class/power_supply/AC* /sys/class/power_supply/ACAD* /sys/class/power_supply/AC0*; do
    [ -e "$path/online" ] && AC="$path" && break
done

safe_cat(){ cat "$1" 2>/dev/null || echo 0; }

# toggle click mode
if [ "$1" = "toggle" ]; then
  [ -f "$TOGGLE" ] && rm -f "$TOGGLE" || touch "$TOGGLE"
fi

# read battery (ignore very small readings)
read_bat(){
  local b="$1"
  local now=$(safe_cat "$b/energy_now")
  local full=$(safe_cat "$b/energy_full")
  if [ "$now" -lt 3000 ]; then
    now=0; full=0
  fi
  echo "$now $full"
}

r0=( $(read_bat "$BAT0") )
r1=( $(read_bat "$BAT1") )
now=$(( r0[0] + r1[0] ))
full=$(( r0[1] + r1[1] ))

percent=0
[ "$full" -gt 0 ] && percent=$(( now * 100 / full ))
[ "$percent" -gt 100 ] && percent=100

# moving average smoothing
mkdir -p "$(dirname "$HISTORY")"
echo "$percent" >> "$HISTORY"
tail -n $HIST_N "$HISTORY" > "${HISTORY}.tmp" && mv "${HISTORY}.tmp" "$HISTORY"

sum=0; cnt=0
while IFS= read -r v; do sum=$((sum + v)); cnt=$((cnt + 1)); done < "$HISTORY"
display_percent=$([ "$cnt" -gt 0 ] && echo $((sum / cnt)) || echo "$percent")

# total power_now (mW)
p0=$(safe_cat "$BAT0/power_now")
p1=$(safe_cat "$BAT1/power_now")
power_mw=$((p0 + p1))
[ "$power_mw" -le 0 ] && power_mw=1   # prevent division by zero

# AC detection & battery state
ac_online=$(safe_cat "$AC/online")
if [ "$ac_online" -ge 1 ]; then
    [ "$display_percent" -lt 100 ] && state="charging" || state="full"
else
    state="discharging"
fi

# Select icon
if [ "$state" = "charging" ]; then
    display_text_icon=""
elif [ "$state" = "full" ]; then
    display_text_icon="󱘖"
else
    if [ "$display_percent" -le 10 ]; then display_text_icon="󰂎"
    elif [ "$display_percent" -le 20 ]; then display_text_icon="󰁺"
    elif [ "$display_percent" -le 30 ]; then display_text_icon="󰁻"
    elif [ "$display_percent" -le 40 ]; then display_text_icon="󰁼"
    elif [ "$display_percent" -le 50 ]; then display_text_icon="󰁽"
    elif [ "$display_percent" -le 60 ]; then display_text_icon="󰁾"
    elif [ "$display_percent" -le 70 ]; then display_text_icon="󰁿"
    elif [ "$display_percent" -le 80 ]; then display_text_icon="󰂀"
    elif [ "$display_percent" -le 90 ]; then display_text_icon="󰁹"
    else display_text_icon="󰂁"
    fi
fi

# Compute time remaining (secs), safely
if [ "$state" = "discharging" ]; then
    secs=$(( now * 3600 / power_mw ))
elif [ "$state" = "charging" ]; then
    secs=$(( (full - now) * 3600 / power_mw ))
else
    secs=0
fi

[ "$secs" -lt 0 ] && secs=0
[ "$secs" -gt 360000 ] && secs=360000  # clamp max ~100 hr

H=$(( secs / 3600 ))
M=$(( (secs % 3600) / 60 ))
alt_time=$([ "$H" -gt 0 ] && echo "${H} hr ${M}m" || echo "${M}m")

# Tooltip with AC power in W
ac_w_mw=$(safe_cat "$AC/power_now")
ac_w=$(awk "BEGIN{printf \"%.2f\", ($ac_w_mw/1000)}")
if [ "$state" = "full" ]; then
    tooltip="Full / ${ac_w}W"
else
    tooltip="$([ "$state" = "charging" ] && echo "Full in ${alt_time} / ${ac_w}W" || echo "${alt_time} / ${ac_w}W")"
fi

# Display text: normal (percent) or alt (time) on toggle
text=$([ -f "$TOGGLE" ] && echo "${display_text_icon} ${alt_time}" || echo "${display_text_icon} ${display_percent}%")

# Sanitize for JSON
escape_json(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
json_text=$(escape_json "$text")
json_tooltip=$(escape_json "$tooltip")
json_alt=$(escape_json "$alt_time")

# Output JSON for Waybar
printf '{"text":"%s","tooltip":"%s","alt":"%s","state":"%s","capacity":%d}\n' \
  "$json_text" "$json_tooltip" "$json_alt" "$state" "$display_percent"



