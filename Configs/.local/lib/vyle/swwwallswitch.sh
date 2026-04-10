#!/usr/bin/env bash
set -eo pipefail

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

source "$scrDir/wallpaper/help.sh"
source "$scrDir/wallpaper/select.sh"
source "$scrDir/wallpaper/core.sh"

wallSel="${wallDir}"
dcolDir="${VYLE_CACHE_HOME}/shell"
blurDir="${VYLE_CACHE_HOME}/blur"
colsDir="${VYLE_CACHE_HOME}/cols"
thumbDir="${VYLE_CACHE_HOME}/thmb"
rofiConf="${rasiDir}/selector.rasi"

[[ -d "${VYLE_CACHE_HOME}" ]] || mkdir -p "${VYLE_CACHE_HOME}"
[[ -d "${blurDir}" ]] || mkdir -p "${blurDir}"
[[ -d "${colsDir}" ]] || mkdir -p "${colsDir}"
[[ -d "${thumbDir}" ]] || mkdir -p "${thumbDir}"

Wall_Switch() {
  OPTIND=1
  local VYLE_IMAGE_SOURCE="" WALLPAPER_SET_FLAGS ntSend="" thmExtn
  while getopts ":i:s:w:n" arg; do
    case "${arg}" in
    i)
      VYLE_IMAGE_SOURCE="${OPTARG}"
      ;;
    w)
      WALLPAPER_SET_FLAGS="${OPTARG}"
      ;;
    n)
      ntSend=false
      ;;
    esac
  done
  shift $((OPTIND - 1))
  if [[ -z "${VYLE_IMAGE_SOURCE}" || ! -f "${VYLE_IMAGE_SOURCE}" ]]; then
    VYLE_IMAGE_SOURCE="${VYLE_CURRENT_IMAGE}"
    if [[ ! -f "${img}" ]]; then
      notify -m 1 -p "Invalid wallpaper?" -u critical -t 900 -a "t1"
      exit 1
    fi
  fi

  VYLE_SOURCE_NO_EXTN="${VYLE_IMAGE_SOURCE##*/}"
  VYLE_SOURCE_NO_EXTN="${VYLE_SOURCE_NO_EXTN%.*}"
  Wall_Initialize

  $ntSend && notify -m 2 -i "theme_engine" -p "${VYLE_IMAGE_SOURCE##*/}" -s "${thumbDir}/${VYLE_SOURCE_NO_EXTN}.thmb" -a "t1" -t 1600
  SWWW_TRANSITION

  if [[ "${WALLBASH_MODE}" -eq 3 && "${dcolMode}" == "theme" ]]; then
    if [[ ! -f "${dcolDir}/auto/${hashMech}.dcol" ]]; then
      ionice -c 3 nice -n 19 "${scrDir}/wallbash.sh" "$VYLE_IMAGE_SOURCE"
    fi
    VYLE_DCOL_PATH="${dcolDir}/auto/${hashMech}.dcol"
  else
    if [[ ! -f "${dcolDir}/${dcolMode}/${hashMech}.dcol" ]]; then
      ionice -c 3 nice -n 19 "${scrDir}/wallbash.sh" "$VYLE_IMAGE_SOURCE"
    fi
    VYLE_DCOL_PATH="${dcolDir}/${dcolMode}/${hashMech}.dcol"
  fi
  [[ -e "${VYLE_DCOL_PATH}" ]] || {
    echo -e "ERROR! DCOL_PATH NOT FOUND!"
    exit 1
  }
  generate_theme "" "${VYLE_CONFIG_HOME}/theme.ivy" ""
  generate_theme "_rgba" "${VYLE_CONFIG_HOME}/theme-rgba.ivy" "_rgba"
  VYLE_THEME=$VYLE_THEME VYLE_CONFIG_HOME=$VYLE_CONFIG_HOME source "${scrDir}/tmq.write.sh"
  "${scrDir}/wallpaper.${wallBackend}.sh" "$VYLE_IMAGE_SOURCE" "$WALLPAPER_SET_FLAGS" &

}

case "${1}" in
-n | -p)
  Wall_Change "$1"
  ;;
-t)
  Wall_Switch ${@}
  ;;
-r)
  mapfile -t random < <(printf '%s\n' "${wallDir}"/*)
  setIdx="${random[RANDOM % ${#random[@]}]}"
  Wall_Switch -i "${random}" -n 1
  ;;
*)
  Wall_Select
  ;;
esac
