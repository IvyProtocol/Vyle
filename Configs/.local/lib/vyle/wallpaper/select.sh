Wall_Select() {
  local wallpapers thumb name
  if [[ -z "${ROFI_WALLPAPER_SCALE}" || "${ROFI_WALLPAPER_SCALE}" -eq 0 ]]; then
    ROFI_WALLPAPER_SCALE=10
  fi
  r_scale="configuration {font : \"${ROFI_WALLPAPER_FONT} ${ROFI_WALLPAPER_SCALE}\";}"
  elem_border=$((hypr_border * 3))

  mon_x_res=$((mon_res * 100 / mon_scale))
  elm_width=$(((28 + 8 + 5) * ROFI_WALLPAPER_SCALE))
  max_avail=$((mon_x_res - (4 * ROFI_WALLPAPER_SCALE)))
  if [[ "${ROFI_WALLPAPER_COLUMN}" -eq 0 || -z "${ROFI_WALLPAPER_COLUMN}" ]]; then
    ROFI_WALLPAPER_COLUMN=$((max_avail / elm_width))
  fi
  r_override="window{width:100%;} 
              listview{columns:${ROFI_WALLPAPER_COLUMN};spacing:5em;}
              element{border-radius:${elem_border}px;orientation:vertical;} 
              element-icon{size:28em;border-radius:0em;} 
              element-text{padding:1em;}"

  choice=$(
    mapfile -d '' wallpapers < <(LC_ALL=C find "${wallSel}" "${WALLPAPER_CONFIGURATION_CUSTOMPATH[@]}" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.jpeg" \) -print0 | sort -Vzf)
    for indx in "${wallpapers[@]}"; do
      name="${indx##*/}"
      thumb="${thumbDir}/${name%.*}.thmb"
      printf "%s\x00icon\x1f%s\n" "$name" "$thumb"
    done | rofi -dmenu -i -p "Wallpaper" -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofiConf}" -select "${VYLE_CURRENT_IMAGE##*/}"
  )
  [[ -z "$choice" ]] && exit 0
  Wall_Switch -i "${wallSel}/$choice" "${WALLPAPER_SWWW_ARGS[@]}"
}
