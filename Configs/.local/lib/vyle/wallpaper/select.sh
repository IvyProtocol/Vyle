Wall_Select() {
  local wallpapers thumb name
  if [[ -z "${rofiWallpaperScale}" || "${rofiWallpaperScale}" -eq 0 ]]; then
    rofiWallpaperScale=10
  fi
  r_scale="configuration {font : \"${rofiWallpaperFont} ${rofiWallpaperScale}\";}"
  elem_border=$((hypr_border * 3))

  mon_x_res=$((mon_res * 100 / mon_scale))
  elm_width=$(((28 + 8 + 5) * rofiWallpaperScale))
  max_avail=$((mon_x_res - (4 * rofiWallpaperScale)))
  if [[ "${rofiWallpaperColumn}" -eq 0 || -z "${rofiWallpaperColumn}" ]]; then
    rofiWallpaperColumn=$((max_avail / elm_width))
  fi
  r_override="window{width:100%;} 
              listview{columns:${rofiWallpaperColumn};spacing:5em;}
              element{border-radius:${elem_border}px;orientation:vertical;} 
              element-icon{size:28em;border-radius:0em;} 
              element-text{padding:1em;}"

  choice=$(
    mapfile -d '' wallpapers < <(LC_ALL=C find "${wallSel}" "${WallAddCustomPath[@]}" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.jpeg" \) -print0 | sort -Vzf)
    for indx in "${wallpapers[@]}"; do
      name="${indx##*/}"
      thumb="${thumbDir}/${name%.*}.thmb"
      printf "%s\x00icon\x1f%s\n" "$name" "$thumb"
    done | rofi -dmenu -i -p "Wallpaper" -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofiConf}" -select "${wallSet##*/}"
  )
  [[ -z "$choice" ]] && exit 0
  Wall_Switch -i "${wallSel}/$choice" "${WALLPAPER_SWWW_ARGS[@]}"
}
