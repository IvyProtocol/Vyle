#!/usr/bin/env bash

generate_help() {
  cat << EOF
Vyle-Project's Wallpaper-Handler interface.
Usage:
  Correct way to use this script is to specify the image into "${BASH_SOURCE[0]##*/}
  ${BASH_SOURCE[0]##*/} [source_img] [flags:optional]

Available Flags:
  next | -n   Set the next wallpaper
  prev | -p   Set the previous wallpaper
  theme | -t  Set the wallpaper with theme animation intended.
EOF
}

SELECTED_WALL="${VYLE_IMAGE_SOURCE:-$1}" 
WALLPAPER_SET_FLAGS="${WALLPAPER_SET_FLAGS:-$2}" 

[ -z "${SELECTED_WALL}" ] && { generate_help; exit 1; }

lockFile="${XDG_RUNTIME_DIR}/${BASH_SOURCE[0]##*/}.lock"

if [ -e "${lockFile}" ]; then
  cat << EOF
Error: There may be another instance of ${BASH_SOURCE[0]##*/} is running.
If you are sure that no other instances is running, remove the lock file.
  $lockFile
EOF
  exit 1
fi

if [[ -z "${VYLE_SHELL_INIT}" && "${VYLE_SHELL_INIT}" -ne 1 ]]; then
  if command -v vyle >/dev/null; then
    eval "$(vyle --init)"
  else
    scrDir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    source "${scrDir}/globalcontrol.sh"
  fi
  trap 'rm -f "${lockFile}"' EXIT
else
  trap 'rm -f "${lockFile}"' RETURN
fi

touch "$lockFile"

case "${WALLPAPER_SET_FLAGS}" in
  -p | --prev)
    xtrans="${wallAnimationPrevious}"
    xtrans="${xtrans:-outer}"
    ;;

  -t | --theme)
    xtrans="${wallAnimationTheme}"
    xtrans="${xtrans:-grow}"
    ;;
  -n | * | --next)
    xtrans="${wallAnimationNext}"
    xtrans="${xtrans:-grow}"
    ;;
esac

if ! ${wallBackend} query &>/dev/null; then
  ${wallBackend}-daemon & disown
  ${wallBackend} query && ${wallBackend} restore
fi

xbezier="${wallTransitionBezier:-.43,1.19,.1,.4}"
xduration="${wallTransDuration:-0.5}"
xframerate="${wallFramerate:-60}"
xpos="$(hyprctl cursorpos | grep -E '^[0-9]' || echo "0,0")"

ionice -c 2 -n 19 ${wallBackend} img "${SELECTED_WALL}" \
  -t "${xtrans}" \
  --transition-bezier "${xbezier}" \
  --transition-duration "${xduration}" \
  --transition-step "${wallTransitionStep}" \
  --transition-fps "${xframerate}" \
  --invert-y \
  --transition-pos "${xpos}"  


