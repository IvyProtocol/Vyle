#!/usr/bin/env bash
set -eo pipefail

scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

export wallDir
wallSel="${wallDir}"
dcolDir="${VYLE_CACHE_HOME}/shell"
cacheDir="${VYLE_CACHE_HOME}/cache"
blurDir="${cacheDir}/blur"
colsDir="${cacheDir}/cols"
thumbDir="${cacheDir}/thumb"
rofiConf="${rasiDir}/selector.rasi"

[[ -d "${blurDir}" ]] || mkdir -p "${blurDir}"
[[ -d "${cacheDir}" ]] || mkdir -p "${cacheDir}"
[[ -d "${colsDir}" ]] || mkdir -p "${colsDir}"
[[ -d "${thumbDir}" ]] || mkdir -p "${thumbDir}"

wallSelTui() {
   OPTIND=1
   local img="" schIPC="" swi="" ntSend=""
   while getopts ":i:s:w:n:" arg; do
       case "$arg" in
           i)    img="$OPTARG"    ;;
           s) schIPC="$OPTARG"    ;;
           w)    swi="$OPTARG"    ;;
           n) ntSend="$OPTARG"    ;;
       esac
   done

    shift $((OPTIND -1))
    if [[ -z "$img" || ! -f "$img" ]]; then
        img=$(fl_wallpaper -r)
        img="${wallDir}/$img"
        [[ ! -f "$img" ]] && notify -m 1 -p "Invalid wallpaper?" -u critical -t 900 -a "t1" && exit 1
    fi

    local base blurred thmExtn 
    base="${img##*/}"
    blurred="${blurDir}/${base%.*}.bpex"
    echo "$img" > "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wallpapers/.wallbash-main" 

    scRun=$(fl_wallpaper -t "${img}" -f 1)    
    case "${rofiThemeStyle}" in
        2)
            thmExtn="quad"
            ;;
        1|*)
            thmExtn="thumb"
            ;;
    esac

    if [[ "$(find "${blurDir}" -maxdepth 0 -empty)" || "$(find "${colsDir}" -maxdepth 0 -empty)" || "$(find "${thumbDir}" -maxdepth 0 -empty)" ]]; then
        echo -e " :: Re-populating cache for ${img}"
        "${scrDir}/swwwallcache.sh" -b "${img}"
    fi

    {   
        setConf "wallSet" "${wallSel}/$(fl_wallpaper -t "$img")" "${VYLE_STATE_HOME}/staterc"
        ln -sf "${colsDir}/${scRun}.cols" "${rasiDir}/wall.cols"
        ln -sf "${blurDir}/${scRun}.bpex" "${rasiDir}/wall.bpex"
        ln -sf "${thumbDir}/${scRun}.sloc" "${rasiDir}/wall.thmb"
        cp "${blurred}" "/usr/share/sddm/themes/silent/backgrounds/default.jpg" 
        ln -sf "${cacheDir}/${thmExtn}/${scRun}.${thmExtn}" "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wall.set"
    } &
    
    echo -e " :: Theme Control - [$(basename "${0}")] - Wallpaper Control - Applying $img"
    [[ "$ntSend" -eq 0 ]] && notify -m 2 -i "theme_engine"  -p "${base}" -s "${thumbDir}/$(fl_wallpaper -t "${img}" -f 1).sloc" -a "t1"
    case $swi in
        --swww-p) swww img "$img" -t "${wallAnimationPrevious}" --transition-bezier "${wallTransitionBezier}" --transition-duration "${wallTransDuration}" --transition-step "${wallTransitionStep}" --transition-fps "${wallFramerate}" --invert-y --transition-pos "$(hyprctl cursorpos | grep -E '^[0-9]' || echo "0,0")" ;;
        --swww-n) swww img "$img" -t "${wallAnimationNext}" --transition-bezier "${wallTransitionBezier}" --transition-duration "${wallTransDuration}" --transition-step "${wallTransitionStep}" --transition-fps "${wallFramerate}" --invert-y --transition-pos "$(hyprctl cursorpos | grep -E '^[0-9]' || echo "0,0")" ;;
        --swww-t) swww img "$img" -t "${wallAnimationTheme}" --transition-bezier "${wallTransitionBezier}" --transition-duration "${wallTransDuration}" --transition-step "${wallTransitionStep}" --transition-fps "${wallFramerate}" --invert-y --transition-pos "$(hyprctl cursorpos | grep -E '^[0-9]' || echo "0,0")" ;;
        *)        swww img "$img" -t "${wallAnimation}" --transition-bezier "${wallTransitionBezier}" --transition-duration "${wallTransDuration}" --transition-step "${wallTransitionStep}" --transition-fps "${wallFramerate}" --invert-y  ;;
    esac
    sleep 0.5
    case "${schIPC}" in
        dark|light) 
            "${scrDir}/ivy-shell.sh" "${img}" --"${schIPC}"
            ;;
        auto)
            "${scrDir}/ivy-shell.sh" "${img}"
            ;;
        theme|*)
            if [[ "${enableWallIde}" -eq 3 && "${dcolMode}" == "theme" ]]; then
                read -r hashMech <<< $(hashmap -v -t "${img}" | awk -F '"' '{print $2}')
                if [[ -f "${dcolDir}/auto/ivy-${hashMech}.dcol" ]]; then
                    cp "${dcolDir}/auto/ivy-${hashMech}.dcol" "${VYLE_CONFIG_HOME}/main/ivygen.dcol"
                    "${scrDir}/modules/ivyshell-theme.sh" && "${scrDir}/modules/ivyshell-helper.sh"
                else
                    "${scrDir}/ivy-shell.sh" "$img"
                fi
            else
                "${scrDir}/ivy-shell.sh" "$img" --"${dcolMode}"
            fi
            ;;
    esac
}

wallSelEnv() {
    if [[ -z "${rofiWallpaperScale}" || "${rofiWallpaperScale}" -eq 0 ]]; then
        rofiWallpaperScale=10
    fi
    r_scale="configuration {font : \"${rofiWallpaperFont} ${rofiWallpaperScale}\";}"
    elem_border=$(( hypr_border * 3 ))

    mon_x_res=$(( mon_res * 100 / mon_scale ))
    elm_width=$(( (28 + 8 + 5) * rofiWallpaperScale ))
    max_avail=$(( mon_x_res - (4 * rofiWallpaperScale) ))
    if [[ "${rofiWallpaperColumn}" -eq 0 || -z "${rofiWallpaperColumn}" ]]; then
        rofiWallpaperColumn=$(( max_avail / elm_width ))
    fi
    r_override="window{width:100%;} listview{columns:${rofiWallpaperColumn};spacing:5em;} element{border-radius:${elem_border}px;orientation:vertical;} element-icon{size:28em;border-radius:0em;} element-text{padding:1em;}"

    local indx files thumb cols blur name
    mapfile -d '' files < <(LC_ALL=C find "${wallSel}" "${WallAddCustomPath[@]}" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.jpeg" \) -print0 | sort -Vzf)
    menu() {
        for indx in "${files[@]}"; do
            name=$(basename "$indx")
            thumb="${thumbDir}/${name%.*}.sloc"
            cols="${colsDir}/${name%.*}.cols"
            blur="${blurDir}/${name%.*}.bpex"
            [[ ! -f "$thumb" || ! -f "$cols" || ! -f "$blur" ]] && "${scrDir}/swwwallcache.sh" -f "$indx"
            printf "%s\x00icon\x1f%s\n" "$name" "$thumb" 
        done
    }
    choice=$(menu | rofi -dmenu -i -p "Wallpaper" -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofiConf}" -select "$(fl_wallpaper -r)")
    [[ -z "$choice" ]] && exit 0
    wallSelTui -i "${wallSel}/$choice"
}

wall_control() {
    local wall wall_i wallCheck wallpapers wallTotal wallFinal swwwTrans
    wallCheck="${1:-}"
    wall="$(fl_wallpaper -r)"

    [[ -n "${wall}" ]] || return 1
    mapfile -t wallpapers < <(LC_ALL=C find "${wallDir}" -maxdepth 1 -mindepth 1 -type f ! -name '.*' -printf '%f\n' | sort -V)

    wall_i=-1
    for indx in "${!wallpapers[@]}"; do 
        [[ "${wallpapers[$indx]}" == "${wall}" ]] && wall_i=$indx
    done

    wallTotal=${#wallpapers[@]}
    case "${wallCheck}" in
        --p) 
            idx=$(( (wall_i - 1 + wallTotal) % wallTotal ));
            swwwTrans="--swww-p"
            ;;
        --n) 
            idx=$(( (wall_i + 1) % wallTotal ));
            swwwTrans="--swww-n"
            ;;
        *) return 1 ;;
    esac
    wallSelTui -i "${wallDir}/${wallpapers[$idx]}" -w "${swwwTrans}" -n 1
}

wallSelRandom() {
    mapfile -t random < <(printf '%s\n' "${wallDir}"/*)
    random="${random[RANDOM % ${#random[@]}]}"
    wallSelTui -i "${random}" -n 1
}

case "${1}" in
    -n)
        wall_control --n
        ;;
    -p)
        wall_control --p
        ;;
    -t)
        wallSelTui ${@}
        ;;
    -r)
        wallSelRandom 
        ;;
    *)
        wallSelEnv
        ;;
esac

