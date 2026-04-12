#!/usr/bin/env bash

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export VYLE_CONFIG_HOME="$XDG_CONFIG_HOME/vyle"
export VYLE_DATA_HOME="$XDG_DATA_HOME/vyle"
export VYLE_STATE_HOME="$XDG_STATE_HOME/vyle"
export VYLE_CACHE_HOME="$XDG_CACHE_HOME/vyle"

dunstDir="$XDG_CONFIG_HOME/dunst"
rasiDir="$XDG_CONFIG_HOME/rofi/shared"
rofiStyleDir="$XDG_CONFIG_HOME/rofi/styles"
rofiAssetDir="$rasiDir/assets"

VYLE_SHELL_INIT=1

set +e
env_pkg() {
  local envPkg statsPkg defAur
  OPTIND=1
  defAur="${defAur:-yay}"

  while getopts "A:H:" opt; do
    case "$opt" in
    A)
      defAur="$OPTARG"
      ;;
    H)
      echo -e " :: Use env_pkg as how pacman works. Example, env_pkg -- -S|-Q|-Ss <package_name>"
      echo -e " :: Use env_pkg to describe the AUR to use with -A. env_pkg -A <aur_helper> -- -<PREFIX> <package_name>"
      return 0
      ;;
    *)
      echo "Invalid option"
      return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))
  if ! command -v "${defAur}" >/dev/null 2>&1; then
    echo -e " :: ${defAur} does not exist! Defaulting to pacman!"
    defAur="pacman"
  fi
  envPkg="$1"
  shift >/dev/null 2>&1

  statsPkg=("$@")
  if [[ "$envPkg" == "-S" ]]; then
    echo -e " :: ${defAur} ${envPkg} is being used!"
    for pkg in "${statsPkg[@]}"; do
      if "${defAur}" -Q "$pkg" &>/dev/null; then
        echo -e " :: ${pkg} is already installed. Skipping..."
        continue
      else
        [[ "${defAur}" == "pacman" ]] && sudo "${defAur}" -S --noconfirm --needed "${pkg}" || "${defAur}" -S --noconfirm --needed "${pkg}"
        [[ "$?" != 0 ]] && echo -e " :: Package ${pkg} failed to install! Manual intervention required!" || echo -e " :: ${pkg} installed successfully!"
      fi
    done
  else
    [[ "${defAur}" == "pacman" ]] && sudo "${defAur}" "${envPkg}" "${statsPkg[@]}" || "${defAur}" "${envPkg}" "${statsPkg[@]}"
    return $?
  fi
}

setConf() {
  set +H
  local varString="${1}"
  local varValue="${2}"
  local varPath="${3}"

  [[ -z "${varValue}" ]] && echo -e "No value has been provided!" && return 1

  local IFS="|!"
  read -ra confStrings <<<"${varString}"
  read -ra confValue <<<"${varValue}"

  for i in "${!confStrings[@]}"; do
    local confKey="${confStrings[i]}"
    local confVal="${confValue[i]}"
    [[ "${confVal}" =~ ^[0-9]+$ ]] || confVal="\"${confVal}\""
    [[ "$(grep -c "^${confKey}" "${varPath}" 2>/dev/null)" -eq 1 ]] && sed -i "s|^${confKey}=.*|${confKey}=${confVal}|" "${varPath}" || echo "${confKey}=${confVal}" >>"${varPath}"

  done
  set -H
}

tomlq() {
  set +H

  print_usage() {
    echo -e "Vyle-Project: TOML Query Tool - tmq."
    echo -e "Usage:\n    $(basename "${0}") [flags|path] [path|group] [group|key] [key|value] [value]"
    echo -e "Available Flags:\n    -i | --inplace  Modify file in-place {required file argument}\n    -o | --output   Read file in-place {required file argument}"
    exit 1
  }

  tmq_write() {
    local IFS="|!"
    read -ra tqGroups <<<"${tomlGroup}"
    read -ra tqKeys <<<"${tomlKey}"
    read -ra tqVals <<<"${tomlValue}"

    for i in "${!tqGroups[@]}"; do
      local tqGroup="${tqGroups[i]}"
      local tqKey="${tqKeys[i]}"
      local tqVal="${tqVals[i]}"

      [[ "${tqVal}" =~ ^[0-9]+$ ]] || tqVal="\"${tqVal}\""

      if ! grep -q "^\[${tqGroup}\]" "${tomlPath}" 2>/dev/null; then
        printf "\n[%s]\n%s=%s\n" "${tqGroup}" "${tqKey}" "${tqVal}" >>"${tomlPath}"
        continue
      fi

      if sed -n "/^\[${tqGroup}\]/,/^\[/p" "${tomlPath}" | grep -q "^${tqKey}[[:space:]]*="; then
        sed -i "/^\[${tqGroup}\]/,/^\[/ s|^\([[:space:]]*${tqKey}[[:space:]]*=[[:space:]]*\)\(.*\)\(\s*#.*\)\?$|\1${tqVal}\3|" "${tomlPath}"
      else
        sed -i "/^\[${tqGroup}\]/a ${tqKey} = ${tqVal}" "${tomlPath}"
      fi
    done
  }

  tmq_read() {
    local group_esc="${tomlGroup//./\\.}"
    rawVal=$(sed -n "/^\[${group_esc}\]/,/^\[/p" "$tomlPath" |
      grep "^${tomlKey}[[:space:]]*=" |
      sed -E "s/^${tomlKey}[[:space:]]*=[[:space:]]*(.*)/\1/; s/[[:space:]]+#.*$//; s/'//g")

    if [[ "$rawVal" =~ ^\$\(|^\$\{ ]]; then
      printf '%s\n' "$rawVal"
    else
      rawVal=$(echo "$rawVal" | sed -E 's/([^\"]*)#.*/\1/')
      rawVal="${rawVal//\'/}"
      rawVal="${rawVal//[\[\]]/}"
      printf '%s\n' "$rawVal"
    fi
  }

  case "${1}" in
  -i | --inplace)
    shift
    local tomlPath=$1
    local tomlGroup=$2
    local tomlKey=$3
    local tomlValue=$4
    tmq_write "${tomlPath}" "${tomlGroup}" "${tomlKey}" "${tomlValue}"
    ;;

  -o | --output)
    shift
    local tomlPath="$1"
    local tomlGroup="$2"
    local tomlKey="$3"

    if [[ -z "${tomlPath}" || -z "${tomlGroup}" || -z "${tomlKey}" ]]; then
      print_usage
    fi

    if ((${#tqGroups[@]} != ${#tqKeys[@]} || ${#tqGroups[@]} != ${#tqVals[@]})); then
      echo "Vyle-Project - Tomlq: group/key/value count mismatch" >&2
      exit 1
    fi

    tmq_read "${tomlPath}" "${tomlGroup}" "${tomlKey}"
    ;;

  -e)
    awk 'BEGIN { FS="="; OFS="=" }
function trim(s,    t) {
    t = s
    sub(/^[ \t\r\n]+/, "", t)
    sub(/[ \t\r\n]+$/, "", t)
    return t
}

function parse_array(s, items,    i, len, ch, buf, inquote, n) {
    len = length(s); i = 1; n = 0; buf = ""; inquote = 0
    while (i <= len) {
        ch = substr(s, i, 1)
        if (!inquote && (ch == "," || ch ~ /[ \t\r\n]/)) {
            if (buf != "") { n++; items[n] = buf; buf = "" }
            i++; continue
        }
        if (ch == "\"") {
            i++
            while (i <= len) {
                ch = substr(s, i, 1)
                if (ch == "\\" && substr(s, i+1, 1) == "\"") { buf = buf "\""; i += 2; continue }
                if (ch == "\"") { i++; break }
                buf = buf ch
                i++
            }
            n++; items[n] = buf; buf = ""
            continue
        }
        while (i <= len) {
            ch = substr(s, i, 1)
            if (ch == "," || ch ~ /[ \t\r\n]/) break
            buf = buf ch
            i++
        }
        if (buf != "") { n++; items[n] = buf; buf = "" }
    }
    if (buf != "") { n++; items[n] = buf }
    for (j = 1; j <= n; j++) items[j] = trim(items[j])
    return n
}

# SECTION header line
/^\s*\[/ {
    gsub(/^\[|\]$/, "", $0)
    section = toupper($0)
    gsub(/\./, "_", section)
    next
}

# key = value lines
/^\s*[^#].*=.*/ {
    key = $1
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    key = toupper(key)

    line = $0
    pos = index(line, "=")
    value = ""
    if (pos > 0) { value = substr(line, pos+1) }
    value = trim(value)

    if (match(value, /^".*"/)) { }
    else { sub(/#[ \t]*.*$/, "", value); value = trim(value) }

    gsub(/'\''/, "", value)

    if (value ~ /^\[.*\]$/) {
        inner = substr(value, 2, length(value)-2)
        count = parse_array(inner, items)
        out = "("
        for (i = 1; i <= count; i++) {
            item = items[i]
            gsub(/"/, "\\\"", item)
            out = out sprintf(" \"%s\"", item)
        }
        out = out " )"
        print "export " section "_" key "=" out
    }
    else if (value ~ /^".*"$/) {
        print "export " section "_" key "=" value
    }
    else if (value ~ /^[0-9]+$/) {
        print "export " section "_" key "=" value
    }
    else {
        print "export " section "_" key "=" value
    }
}
' "${VYLE_CONFIG_HOME}/vyle.toml" >"${VYLE_DATA_HOME}/staterc.conf"
    ;;

  *)
    print_usage
    ;;
  esac

  set -H
}

notify() {
  OPTIND=1
  local modern="" swayncIPath="" printOut="" notify_id="" value="" notif_file="" time="" style="" umode=""

  while getopts ":m:s:p:i:v:t:a:u:" prefix; do
    case "${prefix}" in
    m) modern="${OPTARG}" ;;
    s)
      swayncIPath="${OPTARG}"
      ;;
    p)
      printOut="${OPTARG}"
      ;;
    i)
      notify_id="${OPTARG}"
      ;;
    v)
      value="${OPTARG}"
      ;;
    t)
      time="${OPTARG}"
      ;;
    a)
      style="${OPTARG}"
      ;;
    u)
      umode="${OPTARG}"
      ;;
    \?)
      return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))
  if [[ "${modern}" -eq 2 ]]; then
    notify-send -e -h "string:x-canonical-private-synchronous:${notify_id}" ${value:+-h int:value:${value}} ${umode:+-u ${umode}} ${time:+-t ${time}} ${style:+-a "${style}"} ${swayncIPath:+-i "${swayncIPath}"} "$printOut"
  elif [[ "${modern}" -eq 1 ]]; then
    notif_file="/tmp/${USER}_notif_id"
    notif_id=""

    [[ -f "${notif_file}" ]] && notif_id=$(<"${notif_file}")
    if [[ -n "$notif_id" ]]; then
      notify-send -r "${notif_id}" "${printOut}" ${umode:+-u ${umode}} ${style:+-a ${style}} ${time:+-t ${time}} ${swayncIPath:+-i "${swayncIPath}"} -p
    else
      notif_id=$(notify-send "${printOut}" ${time:+-t ${time}} ${umode:+-u ${umode}} ${swayncIPath:+-i "${swayncIPath}"} -p)
      echo "${notif_id}" >"${notif_file}"
    fi
  else
    [[ -z "${OPTARG}" ]] && {
      echo -e "[$0] Correct arguments are:"
      echo -e "[$0] -l, legacy usage of notif_id. Supports: -s, -p."
      echo -e "[$0] -m, private usage of notify-send. Supports: -s, -p, -i, -v. Mandatorial: -p, -i."
      echo -e "[$0] -p, print inputted message." #If two -p are seen, then the second input would overlap!
      echo -e "[$0] -i, increament notif_id to notify-send. Mandatory if -m 2 was used."
      echo -e "[$0] -v, value set for notify-send, optional."
      exit 1
    }
  fi
}

timestamp() {
  local timestamp
  timestamp=$(date +"%d-%b_%H-%M-%S")
  echo "${timestamp}"
}

prompt_timer() {
  set +e
  unset PROMPT_INPUT
  local timsec=$1
  local msg=$2
  while [[ ${timsec} -ge 0 ]]; do
    echo -ne "\r :: ${msg} (${timsec}s) : "
    read -rt 1 -n 1 PROMPT_INPUT && break
    ((timsec--))
  done
  export PROMPT_INPUT
  echo ""
  set -e
}

set +e

hashmap() {
  unset hashpref
  unset hashMap

  wallHash=()
  wallList=()
  OPTIND=1
  while getopts ":v:t:" hashpref; do
    case "$hashpref" in
    v) verboseMap=1 ;;
    t) target="$OPTARG" ;;
    esac
  done
  shift $((OPTIND - 1))

  for src in "$@"; do
    hashMap=$(find "$src" -type f \( -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -exec md5sum {} + | sort -Vf)

    if [[ -z "${hashMap}" ]]; then
      echo "WARNING: No image found in \"${src}\""
      continue
    fi

    while read -r shaMap img; do
      wallHash+=("${shaMap}")
      wallList+=("${img}")
    done <<<"${hashMap}"

    if [[ "${verboseMap}" -eq 1 ]]; then
      for indx in "${!wallHash[@]}"; do
        echo ":: \${wallHash[${indx}]}=\"${wallHash[indx]}\" :: \${wallList[${indx}]}=\"${wallList[indx]}\""
      done
    fi
  done
}

srcf_rcall() {
  local sr_call="${sr_call:-${1}}"
  return $?
}

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE}" ]] && command -v hyprctl jq >/dev/null; then
  export hypr_border="$(hyprctl -j getoption decoration:rounding | jq '.int')"
  export hypr_width="$(hyprctl -j getoption general:border_size | jq '.int')"
  mon_res=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .width')
  mon_scale=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .scale' | tr -d '.')
fi

ext_thumb() {
  local x_arg x_arg_temp
  x_arg=$(realpath "$x_arg")
  x_arg_temp=$2
  [[ -z "${x_arg}" ]] && return 1
  ffmpeg -y -i "${x_arg}" -vf "thumbnail,scale=1000:-1" -frames:v 1 -update 1 "${x_arg_temp}" &>/dev/null
}

generate_theme() {
  local suffix="$1"
  local target="$2"
  local src_suffix="$3"

  declare -A ivy
  while IFS= read -r line || [[ -n $line ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z $line || $line == \#* ]] && continue
    [[ $line != dcol_* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    key="${key#"${key%%[![:space:]]*}"}"

    val="${val//\\/}"
    val="${val//\"/}"

    ivy["$key"]="$val"
  done <"${VYLE_DCOL_PATH}"
  tmpfile="$(mktemp)"
  {
    echo "wallbash_mode=${ivy[dcol_mode]}"
    for block in {1..4}; do
      echo "wallbash_pry${block}${suffix}=${ivy[dcol_pry$((block))${src_suffix}]}"
      echo "wallbash_txt${block}${suffix}=${ivy[dcol_txt$((block))${src_suffix}]}"

      for i in {1..9}; do
        echo "wallbash_$(((block)))xa${i}${suffix}=${ivy[dcol_$((block))xa${i}${src_suffix}]}"
      done

    done
  } >"$tmpfile"
  mv "${tmpfile}" "$target"
  rm -rf "${tmpfile}"
}

load_ivy_file() {
  local file="$1"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" == *=* ]]; then
      key="${line%%=*}"
      value="${line#*=}"
      [[ "$value" == \#* ]] && value="${value#\#}"
      export "$key=$value"
    fi
  done <"$file"
}
source "${VYLE_DATA_HOME}/staterc.conf"
source "${VYLE_STATE_HOME}/staterc"

case "${WALLBASH_MODE}" in
1)
  dcolMode="dark"
  ;;
2)
  dcolMode="light"
  ;;
3)
  dcolMode="theme"
  ;;
0 | *)
  WALLBASH_MODE=0
  dcolMode="auto"
  ;;
esac

[[ "${WALLPAPER_SWWW_FRAMERATE}" =~ ^[0-9]+$ ]] || WALLPAPER_SWWW_FRAMERATE=144
[[ "${BRIGHTNESS_STEPS}" =~ ^[0-9]+$ ]] || BRIGHTNESS_STEPS=5
[[ "${BRIGHTNESS_NOTIFY_MUTE}" =~ ^[0-9]+$ ]] || BRIGHTNESS_NOTIFY_MUTE=0
[[ "${VOLUME_STEPS}" =~ ^[0-9]+$ ]] || VOLUME_STEPS=5
[[ "${VOLUME_STEPS_MUTE}" =~ ^[0-9]+$ ]] || VOLUME_STEPS_MUTE=0
[[ "${VOLUME_NOTIFY_MUTE}" =~ ^[0-9]+$ ]] || VOLUME_NOTIFY_MUTE=0
[[ "${ROFI_LAUNCH_SCALE}" =~ ^[0-9]+$ ]] || ROFI_LAUNCH_SCALE=10
[[ "${ROFI_LAUNCH_STYLE}" =~ ^[0-9]+$ ]] || ROFI_LAUNCH_STYLE=1
[[ "${ROFI_SWITCH_SCALE}" =~ ^[0-9]+$ ]] || ROFI_SWITCH_SCALE=10
[[ "${NOTIFICATION_FONT_SIZE}" =~ ^[0-9]+$ ]] || NOTIFICATION_FONT_SIZE=10
[[ "${HYPRLAND_CURSOR_SIZE}" =~ ^[0-9]+$ ]] || HYPRLAND_CURSOR_SIZE=20

if [[ "${VYLE_CONFIGURATION_CORE}" == "$(nproc)" ]] || ([[ "${VYLE_CONFIGURATION_CORE}" =~ ^[0-9]+$ ]] && ((VYLE_CONFIGURATION_CORE >= 1 && VYLE_CONFIGURATION_CORE <= $(nproc)))); then
  true
else
  notify -m 2 -i "ERR" -s "${dunstDir}/icons/hyprdots.svg" -t 900 -u critical \
    -p "[$0] ERR: Invalid integer ${VYLE_CONFIGURATION_CORE} that is greater than NPROC: $(nproc)" &
  VYLE_CONFIGURATION_CORE="$(nproc)"
fi

FontRegex='^[[:alnum:] ./+_$&*()!-]+$'
[[ "${GTK_FONT_SIZE}" =~ ${FontRegex} ]] || GTK_FONT_SIZE=12
[[ "${GTK_DOCUMENT_FONT_SIZE}" =~ ${FontRegex} ]] || GTK_DOCUMENT_FONT_SIZE=10
[[ "${GTK_MONOSPACE_FONT_SIZE}" =~ ${FontRegex} || -z "$GTK_MONOSPACE_FONT_SIZE" ]] || GTK_MONOSPACE_FONT_SIZE=10

[[ "${WALLPAPER_SWWW_TRANSITION_DURATION}" =~ ${FontRegex} ]] || WALLPAPER_SWWW_TRANSITION_DURATION=0.5
[[ "${WALLPAPER_SWWW_TRANSITION_BEZIER}" =~ ${FontRegex} ]] || WALLPAPER_SWWW_TRANSITION_BEZIER=".43,1.19,1,.4"
unset FontRegex

WALLPAPER_SWWW_TRANSITION_STEPS=$(awk -v d="$WALLPAPER_SWWW_TRANSITION_DURATION" -v f="$WALLPAPER_SWWW_FRAMERATE" 'BEGIN {printf "%d", d*f + 31}')

FontRegex='^[[:alpha:] ,./+_$&*()!-]+$'
[[ "${HYPRLAND_TERMINAL}" =~ ${FontRegex} ]] || HYPRLAND_TERMINAL="kitty"
[[ "${HYPRLAND_EDITOR}" =~ ${FontRegex} ]] || HYPRLAND_EDITOR="vscodium"
[[ "${HYPRLAND_EXPLORER}" =~ ${FontRegex} ]] || HYPRLAND_EXPLORER="dolphin"
[[ "${HYPRLAND_BROWSER}" =~ ${FontRegex} ]] || HYPRLAND_BROWSER="firefox"
[[ "${HYPRLAND_LOCK_SCREEN}" =~ ${FontRegex} ]] || HYPRLAND_LOCK_SCREEN="hyprlock"
[[ "${HYPRLAND_TASK_MANAGER}" =~ ${FontRegex} ]] || HYPRLAND_TASK_MANAGER="gnome-system-monitor"
[[ "${HYPRLAND_CURSOR_THEME}" =~ ${FontRegex} ]] || HYPRLAND_CURSOR_THEME="Bibata-Modern-Ice"

[[ "${WALLPAPER_SWWW_ANIMATION_PREVIOUS}" =~ ${FontRegex} ]] || WALLPAPER_SWWW_ANIMATION_PREVIOUS="outer"
[[ "${WALLPAPER_SWWW_ANIMATION_NEXT}" =~ ${FontRegex} ]] || WALLPAPER_SWWW_ANIMATION_NEXT="grow"
[[ "${WALLPAPER_SWWW_ANIMATION_THEME}" =~ ${FontRegex} ]] || WALLPAPER_SWWW_ANIMATION_THEME="grow"
[[ "${WALLPAPER_CONFIGURATION_BACKEND}" =~ ${FontRegex} ]] || WALLPAPER_CONFIGURATION_BACKEND="awww"

if [[ "${BRIGHTNESS_FETCHICON}" =~ ${FontRegex} ]]; then
  if [[ ! -d "${BRIGHTNESS_FETCHICON}" ]]; then
    notify -m 2 -i "ERROR" -t 1200 -s "${dunstDir}/icons/hyprdots.svg" -u critical -p "ERROR! Invalid string-type \"${BRIGHTNESS_FETCHICON}\" -!" &
    BRIGHTNESS_FETCHICON="${dunstDir}/icons/vol"
  fi
else
  BRIGHTNESS_FETCHICON="${dunstDir}/icons/vol"
  if [[ ! -d "${BRIGHTNESS_FETCHICON}" ]]; then
    notify -m 2 -i "ERROR" -t 1200 -s "${dunstDir}/icons/hyprdots.svg" -u critical -p "ERROR! Missing \"${dunstDir}/icons/vol\"" &
  fi
fi

if [[ "${VOLUME_FETCHICON}" =~ ${FontRegex} ]]; then
  if [[ ! -d "${VOLUME_FETCHICON}" ]]; then
    notify -m 2 -i "ERROR" -t 1200 -s "${dunstDir}/icons/hyprdots.svg" -u critical -p "ERROR! Invalid string-type \"${VOLUME_FETCHICON}\" -!" &
    VOLUME_FETCHICON="${dunstDir}/icons/vol"
  fi
else
  VOLUME_FETCHICON="${dunstDir}/icons/vol"
  if [[ ! -d "${VOLUME_FETCHICON}" ]]; then
    notify -m 2 -i "ERROR" -t 1200 -s "${dunstDir}/icons/hyprdots.svg" -u critical -p "ERROR! Missing \"${dunstDir}/icons/vol\" -!" &
  fi
fi

[[ "${GTK_FONT_NAME}" =~ ${FontRegex} ]] || GTK_FONT_NAME="JetBrainsMono Nerd Font Regular"
[[ "${GTK_DOCUMENT_FONT}" =~ ${FontRegex} ]] || GTK_DOCUMENT_FONT="JetBrainsMono Nerd Font Regular"
[[ "${GTK_MONOSPACE_FONT}" =~ ${FontRegex} ]] || GTK_MONOSPACE_FONT="JetBrainsMono Nerd Font Regular"
[[ "${GTK_FONT_ANTIALIASING}" =~ ${FontRegex} ]] || GTK_FONT_ANTIALIASING="rgba"
[[ "${GTK_FONT_HINTING}" =~ ${FontRegex} ]] || GTK_FONT_HINTING="slight"

[[ "${ROFI_LAUNCH_FONT}" =~ ${FontRegex} ]] || ROFI_LAUNCH_FONT="JetBrainsMono Nerd Font"
[[ "${ROFI_WALLPAPER_FONT}" =~ ${FontRegex} ]] || ROFI_WALLPAPER_FONT="JetBrainsMono Nerd Font"
[[ "${ROFI_THEME_FONT}" =~ ${FontRegex} ]] || ROFI_THEME_FONT="JetBrainsMono Nerd Font"
[[ "${ROFI_WALLBASH_FONT}" =~ ${FontRegex} ]] || ROFI_WALLBASH_FONT="JetBrainsMono Nerd Font"
[[ "${NOTIFICATION_FONT_NAME}" =~ ${FontRegex} ]] || NOTIFICATION_FONT_NAME="JetBrainsMono Nerd Font"
unset FontRegex

export \
  VYLE_THEME \
  GTK_FONT_NAME \
  WALLBASH_MODE \
  GTK_FONT_SIZE \
  HYPRLAND_EXPLORER \
  GTK_FONT_ANTIALIASING \
  GTK_DOCUMENT_FONT_SIZE \
  GTK_MONOSPACE_FONT_SIZE \
  VYLE_CURRENT_IMAGE \
  VYLE_RESERVED_THEME \
  VYLE_CONFIGURATION_CORE \
  HYPRLAND_CURSOR_SIZE \
  HYPRLAND_TASK_MANAGER \
  VYLE_SHELL_INIT \
  GTK_FONT_HINTING \
  GTK_DOCUMENT_FONT \
  GTK_MONOSPACE_FONT \
  HYPRLAND_EDITOR \
  HYPRLAND_BROWSER \
  HYPRLAND_TERMINAL \
  VOLUME_FETCHICON \
  VOLUME_STEPS \
  VOLUME_STEPS_MUTE \
  VOLUME_NOTIFY_MUTE \
  BRIGHTNESS_STEPS \
  BRIGHTNESS_NOTIFY_MUTE \
  BRIGHTNESS_FETCHICON \
  NOTIFICATION_FONT_NAME \
  NOTIFICATION_FONT_SIZE \
  HYPRLAND_LOCK_SCREEN \
  WALLPAPER_SWWW_FRAMERATE \
  WALLPAPER_CONFIGURATION_BACKEND \
  WALLPAPER_SWWW_TRANSITION_DURATION \
  WALLPAPER_SWWW_TRANSITION_BEZIER \
  WALLPAPER_SWWW_TRANSITION_STEPS \
  WALLPAPER_SWWW_ANIMATION_PREVIOUS \
  WALLPAPER_SWWW_ANIMATION_NEXT \
  WALLPAPER_SWWW_ANIMATION_THEME \
  ROFI_LAUNCH_FONT \
  ROFI_LAUNCH_SCALE \
  ROFI_LAUNCH_STYLE \
  ROFI_THEME_FONT \
  ROFI_THEME_SCALE \
  ROFI_THEME_COLUMN \
  ROFI_THEME_STYLE \
  ROFI_SWITCH_SCALE \
  ROFI_SWITCH_COLUMN \
  ROFI_WALLBASH_FONT \
  HYPRLAND_CURSOR_THEME
