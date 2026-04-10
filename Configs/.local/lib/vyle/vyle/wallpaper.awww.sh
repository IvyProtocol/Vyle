#!/usr/bin/env bash
generate_help() {
  cat <<EOF
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

[ -z "${SELECTED_WALL}" ] && {
  generate_help
  exit 1
}

lockFile="${XDG_RUNTIME_DIR}/${BASH_SOURCE[0]##*/}.lock"

if [ -e "${lockFile}" ]; then
  cat <<EOF
Error: There may be another instance of ${BASH_SOURCE[0]##*/} is running.
If you are sure that no other instances is running, remove the lock file.
  $lockFile
EOF
  exit 1
fi

trap 'rm -f "${lockFile}"' EXIT
touch "$lockFile"

scrDir="$(dirname "$(realpath "$0")")"
source "$scrDir/globalcontrol.sh"

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
  awww-daemon --format xrgb &
  disown
  awww query && ${wallBackend} restore
fi

xbezier="${wallTransitionBezier:-.43,1.19,.1,.4}"
xduration="${wallTransDuration:-0.5}"
xframerate="${wallFramerate:-60}"
xpos="$(hyprctl cursorpos | grep -E '^[0-9]' || echo "0,0")"

awww img "${SELECTED_WALL}" \
  -t "${xtrans}" \
  --transition-bezier "${xbezier}" \
  --transition-duration "${xduration}" \
  --transition-step "${wallTransitionStep}" \
  --transition-fps "${xframerate}" \
  --invert-y \
  --transition-pos "${xpos}"
