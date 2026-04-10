#!/usr/bin/env bash
set -eo pipefail
[[ $VYLE_SHELL_INIT -ne 1 ]] && eval "$(vyle --init)"

if [[ -z "${VYLE_SHELL_INIT}" ]]; then
  scrDir="$(dirname "$(realpath "$0")")"
  source "${scrDir}/globalcontrol.sh"
fi

#// Credits to sl1ng for the orginal script. Rewritten by Vyle.
ctlcheck=("pactl" "jq" "notify-send" "awk" "pgrep" "hyprctl" "iconv")
missing=()

for ctl in "${ctlcheck[@]}"; do
  command -v "${ctl}" >/dev/null || missing+=("${ctl}")
done

if ((${#missing[@]})); then
  if printf '%s\n' "${missing[@]}" | grep -qx "pactl"; then
    printf '%s\n' "${missing[@]}" | grep -qx "notify-send" || notify-send -a "t1" -u critical -r 91190 -t 2000 -i "${dunstDir}/icons/hyprdots.svg" "Pactl Not Installed!"
  fi
  echo "Missing required dependencies: \"${missing[*]}\"" >&2
  exit 1
fi

#// Parse .pid, .class, .title to __pid, __class, __title.
active_json="$(hyprctl -j activewindow 2>/dev/null)" || {
  echo "Did hyprctl fail to run? [EXIT-CODE:-1]" >&2
  exit 1
}
PID="$(jq -r '"\(.pid)\t\(.class)\t\(.title)\t\(.initialTitle)"' <<<"${active_json}")" || {
  echo "Did jq fail to run? [EXIT-CODE:-1]" >&2
  exit 1
}

IFS=$'\t' read -r __pid __class __title __initialTitle <<<"${PID}"

[[ -z "${__pid}" || "${__pid}" == "null" || "${__pid}" -le 0 ]] 2>/dev/null && {
  echo "Could not resolve PID for focused window." >&2
  exit 1
}
sink_json="$(pactl -f json list sink-inputs 2>/dev/null | iconv -f utf-8 -t utf-8 -c)" || {
  echo "Did pactl or iconv fail to run? Required manual intervention." >&2
  exit 1
}

#// Collect all descendant PIDs for the active window (Chrome/Wayland audio often runs in child processes).
declare -A seen_pids=()
queue=("${__pid}")
all_pids=()
while ((${#queue[@]})); do
  pid="${queue[0]}"
  queue=("${queue[@]:1}")
  [[ -n "${seen_pids[$pid]:-}" ]] && continue
  seen_pids["$pid"]=1
  all_pids+=("$pid")
  mapfile -t children < <(pgrep -P "$pid" || true)
  for child in "${children[@]}"; do
    [[ -n "${seen_pids[$child]:-}" ]] || queue+=("$child")
  done
done
idsJson="$(printf '%s\n' "${all_pids[@]}" | jq -s 'map(tonumber)')"

#// Check if any descendant PID matches application.process.id or else verify other statements.
mapfile -t sink_ids < <(
  jq -r --argjson pids "${idsJson}" --arg class "${__class}" --arg title "${__title}" '
.[] |
 def lc(x): (x // "" | ascii_downcase);
  def normalize(x): x | gsub("[-_~.]+";" ") ;
  select(
  ((.properties["application.process.id"] | tostring | (tonumber? // null)) as $p | $p != null and ($pids | index($p) != null))
  or
  ($class != "" and (lc(.properties["application.name"]) | contains(lc($class))))
  or
  ($class != "" and (lc(.properties["application.id"]) | contains(lc($class))))
  or
  ($class != "" and (lc(.properties["application.process.binary"]) | contains(lc($class))))
  or
  ($title != "" and (normalize(lc(.properties["media.name"])) | contains(normalize(lc($title)))))
  ) | .index' <<<"${sink_json}"
)

if [[ "${#sink_ids[@]}" -eq 0 ]]; then
  mapfile -t fallback_pids < <(pgrep -x "${__class}" || true)
  if [[ "${#fallback_pids[@]}" -gt 0 ]]; then
    declare -A seen_fallback=()
    queue=("${fallback_pids[@]}")
    all_fallback=()
    while ((${#queue[@]})); do
      pid="${queue[0]}"
      queue=("${queue[@]:1}")
      [[ -n "${seen_fallback[$pid]:-}" ]] && continue
      seen_fallback["$pid"]=1
      all_fallback+=("$pid")
      mapfile -t children < <(pgrep -P "$pid" || true)
      for child in "${children[@]}"; do
        [[ -n "${seen_fallback[$child]:-}" ]] || queue+=("$child")
      done
    done
    fallbackJson="$(printf '%s\n' "${all_fallback[@]}" | jq -s 'map(tonumber)')"
    mapfile -t sink_ids < <(jq -r --argjson pids "${fallbackJson}" '.[] | 
      select(((.properties["application.process.id"] | tostring | (tonumber? // null)) as $p | $p != null and ($pids | index($p)))) | .index' <<<"${sink_json}")
  fi
fi

#// Detect $HYPRLAND_INSTANCE_SIGNATURE to trigger and dispatch error code.
if [[ ${#sink_ids[@]} -eq 0 ]]; then
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE}" ]]; then
    # If even the fallback_pid remains empty, we will dispatch exit code based on $HYPRLAND_INSTANCE_SIGNATURE.
    notify-send -a "t1" -r 91190 -t 1200 -i "${dunstDir}/icons/hyprdots.svg" "No sink input available."
    echo "No sink input for focused window: ${__class}" >&2
    exit 1
  else
    echo "No sink input for focused active_window ${__class}" >&2
    exit 1
  fi
fi

idsJson=$(printf '%s\n' "${sink_ids[@]}" | jq -s 'map(tonumber)')

#// Get the available option from pactl.
want_mute=$(
  jq -r --argjson ids "$idsJson" '
    [ .[] | select(.index as $i | $ids | index($i)) | .mute ] as $m |
    if all($m[]; . == true) then "no"
    else "yes"
    end' <<<"${sink_json}"
)

if [[ "${want_mute}" == "no" ]]; then
  state_msg="Unmuted"
  swayIcon="${dunstDir}/icons/vol/unmuted-speaker.svg"
else
  state_msg="Muted"
  swayIcon="${dunstDir}/icons/vol/muted-speaker.svg"
fi

[[ -f "${swayIcon}" ]] || {
  echo -e "Missing swaync icons." >&2
  swayIcon=""
}

errors=0
for id in "${sink_ids[@]}"; do
  pactl set-sink-input-mute "$id" "$want_mute" || ((++errors))
done

if ((errors)); then
  echo -e "pactl failed to set \"${id}\" to be \"${state_msg}\"! Manual intervention required." >&2
  notify-send -a "t1" -r 91190 -t 1200 -u critical -i "${dunstDir}/icons/hyprdots.svg" "Failed to change sink input(s) \"${id}\":-\"${state_msg}\"!"
else
  # // Append paxmier to get a nice result. Pamixer is complete optional here.
  if command -v pamixer >/dev/null; then
    notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__initialTitle}" "$(pamixer --get-default-sink | awk -F '"' 'END{print $(NF - 1)}' || true)"
  else
    notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__initialTitle}"
  fi
fi
