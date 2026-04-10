#!/usr/bin/env bash
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

flag="${VYLE_CACHE_HOME}/done"

if [[ ! -e "$flag" ]]; then
  "${scrDir}/swwwallswitch.sh" -t -i "${VYLE_CURRENT_IMAGE}" -n --s -w --swww-n >/dev/null 2>&1
  touch "$flag"
fi
