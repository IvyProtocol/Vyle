#!/usr/bin/env bash
set -eo pipefail
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

rasiPath="${rasiDir}/wallbash.rasi"

apply_config() {
  [[ $1 == "auto" ]] && wallIde=0
  [[ $1 == "dark" ]] && wallIde=1
  [[ $1 == "light" ]] && wallIde=2
  [[ $1 == "theme" ]] && wallIde=3

  [[ -n "${WALLBASH_MODE}" ]] && setConf "WALLBASH_MODE" "${wallIde}" "${VYLE_STATE_HOME}/staterc" || setConf "WALLBASH_MODE" "0" "${VYLE_STATE_HOME}/staterc"
  notify -m 2 -i "theme_engine" -p "Theme Mode: $1" -s "${dunstDir}/icons/hyprdots.svg" -t 900 -a "t1"
  [[ ! -e "${scrDir}/wallbash.sh" ]] && exit 1
  if [[ "${wallIde}" -eq 3 ]]; then
    setConf "VYLE_THEME|WALLBASH_MODE" "${VYLE_RESERVED_THEME}|3" "${VYLE_STATE_HOME}/staterc"
    sed -i 's|^[[:space:]]*source[[:space:]]*=[[:space:]]* \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|#source = \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|' "${VYLE_DATA_HOME}/hypr/dynamic.conf"
    VYLE_THEME=$VYLE_RESERVED_THEME

    source "${scrDir}/tmq.write.sh"
    exit 0
  else
    [[ "${VYLE_THEME}" != "Wallbash-Ivy" ]] && setConf "VYLE_THEME" "Wallbash-Ivy" "${VYLE_STATE_HOME}/staterc" &
    sed -i 's|^#[[:space:]]*source[[:space:]]*=[[:space:]]* \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|source = \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|' "${VYLE_DATA_HOME}/hypr/dynamic.conf"
    read -r hashMech <<<"$(md5sum "${VYLE_CURRENT_IMAGE}" | awk '{print $1}')"

    if [[ ! -e "${VYLE_CACHE_HOME}/shell/${1}/${hashMech}.dcol" ]]; then
      "${scrDir}/wallbash.sh" "${VYLE_CURRENT_IMAGE}" --"${1}"
    fi
    VYLE_DCOL_PATH="${VYLE_CACHE_HOME}/shell/${1}/${hashMech}.dcol"
    [[ -e "${VYLE_DCOL_PATH}" ]]

    generate_theme "" "${VYLE_CONFIG_HOME}/theme.ivy" ""
    generate_theme "_rgba" "${VYLE_CONFIG_HOME}/theme-rgba.ivy" "_rgba"
    VYLE_THEME="Wallbash-Ivy"
    VYLE_RESERVED_THEME=$VYLE_RESERVED_THEME
    VYLE_CONFIG_HOME=$VYLE_CONFIG_HOME
    source "${scrDir}/tmq.write.sh"
  fi

  if [[ -z "${VYLE_CURRENT_IMAGE}" && -x "${scrDir}/swwwallswitch.sh" ]]; then
    rnSel=$(find "${wallDir}" -maxpath 1 -type f | shuf -n 1)
    "${scrDir}/swwwallswitch.sh" -i "${rnSel}"
  fi
}

rofi_wallbash() {
  if [[ -z "${ROFI_WALLBASH_SCALE}" || "${ROFI_WALLBASH_SCALE}" -eq 0 ]]; then
    ROFI_WALLBASH_SCALE=10
  fi

  r_scale="configuration {font: \"${ROFI_WALLBASH_FONT} ${ROFI_WALLBASH_SCALE}\";}"
  elem_border=$((hypr_border * 4))
  r_override="window{border-radius:${elem_border}px;} element{border-radius:${elem_border}px;}"

  wallbashModes=(theme auto dark light)
  choice=$(parallel echo {} ::: "${wallbashModes[@]}" |
    rofi -i -dmenu -theme-str "${r_scale}" \
      -theme-str "${r_override}" -config "$rasiPath" \
      -select "${wallbashModes[$(($WALLBASH_MODE + 1))]}")

  [[ -z "$choice" ]] && {
    echo "No option selected. Exiting."
    exit 0
  }
  sleep 0.7
  apply_config "$choice"
}

[[ -z "$1" ]] && rofi_wallbash || apply_config "$1"
