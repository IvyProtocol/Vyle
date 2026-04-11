#!/usr/bin/env sh

# set variables
scrDir="$(dirname "$(realpath "$0")")"
if [[ -e "${scrDir}/globalcontrol.sh" ]]; then
  source "$scrDir/globalcontrol.sh"
else
  eval "$(vyle --init)"
fi

dstDir="${XDG_CONFIG_HOME}/dunst"

export hypr_border NOTIFICATION_FONT_NAME NOTIFICATION_FONT_SIZE
envsubst <"${dstDir}/dunst.conf" >"${dstDir}/dunstrc"
envsubst <"${dstDir}/wallbash.conf" >>"${dstDir}/dunstrc"
dunstctl reload &
