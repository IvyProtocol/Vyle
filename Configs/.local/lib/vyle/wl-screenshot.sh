#!/usr/bin/env bash

scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

lock_File="${XDG_RUNTIME_DIR}/${BASH_SOURCE[0]##*/}.lock"
if [[ -e "${lock_File}" ]]; then
  cat <<EOF
Error: Another instance of ${BASH_SOURCE[0]##*/} is running. 
If you are sure that no other instance is running. Remove the the lock file:
    $lock_File
EOF
  notify-send -a "t2" -r 91190 -t 800 -i "${dunstDir}/icons/hyprdots.svg" "Vyle" "Another instance of ${BASH_SOURCE[0]##*/} is running."
  exit 0
fi
touch "${lock_File}"
trap 'rm -f ${lock_File}' EXIT

dir="$HOME/Pictures/Screenshots"
scrfile="${dir}/Screenshot_$(timestamp).png"

active_window_class=$(hyprctl -j activewindow | jq -r '(.class)')
active_window_file="Screenshot_$(timestamp)_${active_window_class}.png"
active_window_path="${dir}/${active_window_file}"

notify_cmd_base="notify-send -t 2200 -A action1=Open -A action2=Delete -h string:x-canonical-private-synchronous:shot-notify"
notify_cmd_shot="${notify_cmd_base} -i ${dunstDir}/icons/hyprdots.svg"
notify_cmd_shot_win="${notify_cmd_base} -i ${dunstDir}/icons/hyprdots.svg"

# notify and view screenshot
notify_view() {
  if [[ "$1" == "active" ]]; then
    if [[ -e "${active_window_path}" ]]; then
      resp=$(timeout 5 ${notify_cmd_shot_win} " Screenshot of:" " ${active_window_class} Saved.")
      case "$resp" in
      action1)
        xdg-open "${active_window_path}" &
        ;;
      action2)
        rm "${active_window_path}" i &
        ;;
      esac
    else
      ${notify_cmd_shot} " Screenshot of:" " ${active_window_class} NOT Saved."

    fi
  else
    local check_file="${scrfile}"
    if [[ -e "$check_file" ]]; then
      resp=$(timeout 5 ${notify_cmd_shot} " Screenshot" " Saved")
      case "$resp" in
      action1)
        xdg-open "${check_file}" &
        ;;
      action2)
        rm "${check_file}" &
        ;;
      esac
    else
      ${notify_cmd_shot} " Screenshot" " NOT Saved"
    fi
  fi
}

# take shots
shotnow() {
  grim - | tee "$scrfile" | wl-copy
  sleep 2
  notify_view
}

shotarea() {
  tmpfile=$(mktemp)
  grim -g "$(slurp)" - >"$tmpfile"

  # Copy with saving
  if [[ -s "$tmpfile" ]]; then
    wl-copy <"$tmpfile"
    mv "$tmpfile" "$scrfile"
  fi
  notify_view
}

shotactive() {
  active_window_class=$(hyprctl -j activewindow | jq -r '(.class)')
  active_window_file="Screenshot_${times}_${active_window_class}.png"
  active_window_path="${dir}/${active_window_file}"

  hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | grim -g - "${active_window_path}"
  sleep 1
  notify_view "active"
}

if [[ ! -d "$dir" ]]; then
  mkdir -p "$dir"
fi

case "$1" in
--now)
  shotnow
  ;;
--area)
  shotarea
  ;;
--active)
  shotactive
  ;;
*)
  echo -e "Available Options for $(basename \"$0\") : --now --area --active"
  ;;
esac

exit 0
