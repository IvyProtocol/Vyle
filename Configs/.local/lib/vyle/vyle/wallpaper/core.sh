if [ -z $VYLE_SHELL_INIT ]; then
  eval "$(vyle --init)"
fi

Wall_Change() {
  mapfile -t wallpapers < <(LC_ALL=C find "${wallDir}" -maxdepth 1 -mindepth 1 -type f ! -name '.*' -printf '%f\n' | sort -V)

  for indx in "${!wallpapers[@]}"; do
    if [[ "${wallpapers[$indx]}" == "${VYLE_CURRENT_IMAGE##*/}" ]]; then
      if [ "$1" == "-n" ]; then
        setIdx=$(((indx + 1) % ${#wallpapers[@]}))
        swwwTrans="-n"
      elif [ "$1" == "-p" ]; then
        setIdx=$(((indx - 1 + ${#wallpapers[@]}) % ${#wallpapers[@]}))
        swwwTrans="-p"
      else
        echo "No argument has been passed!"
        exit 1
      fi
      break
    fi
  done

  Wall_Switch -i "${wallDir}/${wallpapers[setIdx]}" -w "${swwwTrans}" -n 1
}

SWWW_TRANSITION() {
  case "${WALLPAPER_SET_FLAGS}" in
  "--swww-p" | "--swww-t") ;;
  "--swww-n" | *) ;;
  esac
}

Wall_Initialize() {
  if [ "${rofiThemeStyle}" -eq 2 ]; then
    thmExtn="quad"
  elif [[ "${rofiThemeStyle}" -eq 1 || -z "${rofiThemeStyle}" ]]; then
    thmExtn="thmb"
  fi

  echo "${VYLE_IMAGE_SOURCE}" >"${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wallpapers/.wallbash-main"
  setConf "VYLE_CURRENT_IMAGE" "\${VYLE_CONFIG_HOME}/theme/\${VYLE_RESERVED_THEME}/wallpapers/${VYLE_IMAGE_SOURCE##*/}" "${VYLE_STATE_HOME}/staterc"
  ln -sf "${colsDir}/${VYLE_SOURCE_NO_EXTN}.cols" "${rasiDir}/wall.cols"
  ln -sf "${blurDir}/${VYLE_SOURCE_NO_EXTN}.bpex" "${rasiDir}/wall.bpex"
  ln -sf "${thumbDir}/${VYLE_SOURCE_NO_EXTN}.thmb" "${rasiDir}/wall.thmb"
  ln -sf "${cacheDir}/${thmExtn}/${VYLE_SOURCE_NO_EXTN}.${thmExtn}" "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wall.set"

  read -r hashMech <<<"$(md5sum "${VYLE_IMAGE_SOURCE}" | awk '{print $1}')"
}
