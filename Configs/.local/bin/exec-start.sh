#!/usr/bin/env bash
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

flag="${VYLE_CACHE_HOME}/done"

if ! pgrep -x "swww-daemon" >/dev/null; then
  swww-daemon &
fi

if [[ ! -e "$flag" ]]; then
  "${scrDir}/swwwallswitch.sh" -t -i "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wallpapers/${wallSet##*/}" -n --s -w --swww-n >/dev/null 2>&1
  touch "$flag"
fi
