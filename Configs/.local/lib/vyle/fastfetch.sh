#!/usr/bin/env bash
set -eo pipefail

scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"
fetchIcon="${FASTFETCH_FETCHICON}"
if [[ -e "${fetchIcon}" ]]; then
  fetch=$(find "${fetchIcon}" -maxdepth 1 -type f | shuf -n 1)
  echo "${fetch}"
fi
