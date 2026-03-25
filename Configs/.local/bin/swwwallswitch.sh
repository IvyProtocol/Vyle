#!/usr/bin/env bash
set -eo pipefail

scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

lock_File="${XDG_RUNTIME_DIR}/${0##*/}.lock"
if [[ -e "${lock_File}" ]]; then
    cat << EOF
Error: Another instance of ${0##*/} is running. 
If you are sure that no other instance is running. Remove the the lock file:
    $lock_File
EOF
    notify-send -a "t2" -r 91190 -t 800 -i "${dunstDir}/icons/hyprdots.svg" "Vyle" "Another instance of ${0##*/} is running."
    exit 0
fi
touch "${lock_File}"
trap 'rm -f ${lock_File}' EXIT

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
    local img="" schIPC="" swi="" ntSend="" thmExtn
    while getopts ":i:s:w:n:" arg; do
        case "${arg}" in
            i)
                img="${OPTARG}"
                ;;
            s)
                schIPC="${OPTARG}"
                ;;
            w)
                swi="${OPTARG}"
                ;;
            n)
                ntSend="${OPTARG}"
                ;;
        esac
    done
    shift $((OPTIND - 1))
    if [[ -z "${img}" || ! -f "${img}" ]]; then
        img="${wallSet##*/}"
        img="${wallDir}/${img}"
        
        if [[ ! -f "${img}" ]]; then
            notify -m 1 -p "Invalid wallpaper?" -u critical -t 900 -a "t1"
            exit 1
        fi
    fi
    scRun="$(fl_wallpaper -t "${img}" -f 1)"

    {
        echo "${img}" > "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wallpapers/.wallbash-main"
        echo -e " :: Theme Control - ${0##*/} - Wallpaper Control - Applying ${img}"
        echo -e " :: "
        [[ "${ntSend}" -eq 0 ]] && notify -m 2 -i "theme_engine" -p "${img##*/}" -s "${thumbDir}/$(fl_wallpaper -t "${img}" -f 1).sloc" -a "t1" -t 1600

        case "${rofiThemeStyle}" in
            2)
                thmExtn="quad"
                ;;
            1|*)
                thmExtn="thumb"
                ;;
        esac

        setConf "wallSet" "${wallSel}/${img##*/}" "${VYLE_STATE_HOME}/staterc"
        ln -sf "${colsDir}/${scRun}.cols" "${rasiDir}/wall.cols"
        ln -sf "${blurDir}/${scRun}.bpex" "${rasiDir}/wall.bpex"
        ln -sf "${thumbDir}/${scRun}.sloc" "${rasiDir}/wall.thmb"
        ln -sf "${cacheDir}/${thmExtn}/${scRun}.${thmExtn}" "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/wall.set"
    } &
    
    VYLE_IMAGE_SOURCE="${img}"
    case $swi in
        --swww-p) 
            WALLPAPER_SET_FLAGS="-p"
            ;;
        --swww-t)
            WALLPAPER_SET_FLAGS="-t"
            ;;
        --swww-n | *) 
            WALLPAPER_SET_FLAGS="-n"
            ;;
    esac  
    source "${scrDir}/wallpaper.hybrid.sh"
    sleep 0.6
    case "${schIPC}" in
        dark|light|auto) 
            read -r hashMech <<< "$(md5sum "${img}" | awk '{print $1}')"
            if [[ -f "${dcolDir}/${dcolMode}/ivy-${hashMech}.dcol" ]]; then
                VYLE_DCOL_PATH="${dcolDir}/${dcolMode}/ivy-${hashMech}.dcol"
            else
                if [[ "${schIPC}" == "auto" ]]; then
                    ionice -c 3 nice -n 19 "${scrDir}/wallbash.sh" "${img}"

                else
                    ionice -c 3 nice -n 19 "${scrDir}/wallbash.sh" "${img}" --${schIPC}
                fi
                VYLE_DCOL_PATH="${dcolDir}/${dcolMode}/ivy-${hashMech}.dcol"
            fi
            [[ -e "${VYLE_DCOL_PATH}" ]]
            generate_theem "" "${VYLE_CONFIG_HOME}/theme.ivy" ""
            generate_theme "_rgba" "${VYLE_CONFIG_HOME}/theme-rgba.ivy" "_rgba"
            ionice -c 3 nice -n 19 "${scrDir}/modules/ivyshell-helper.sh"
            ;;
        theme|*)
            if [[ "${enableWallIde}" -eq 3 && "${dcolMode}" == "theme" ]]; then
                read -r hashMech <<< $(hashmap -v -t "${img}" | awk -F '"' '{print $2}')
                if [[ -f "${dcolDir}/auto/ivy-${hashMech}.dcol" ]]; then
                    true
                else
                    ionice -c 3 nice -n 19 "${scrDir}/wallbash.sh" "$img"
                fi
                VYLE_DCOL_PATH="${dcolDir}/auto/ivy-${hashMech}.dcol"
            else
                read -r hashMech <<< "$(md5sum "${img}" | awk '{print $1}')"
                if [[ -f "${dcolDir}/${dcolMode}/ivy-${hashMech}.dcol" ]]; then
                    VYLE_DCOL_PATH="${dcolDir}/${dcolMode}/ivy-${hashMech}.dcol"
                else
                    ionice -c 3 nice -n 19 "${scrDir}/wallbash.sh" "$img"
                    VYLE_DCOL_PATH="${dcolDir}/${dcolMode}/ivy-${hashMech}.dcol"
                fi
            fi
            [[ -e "${VYLE_DCOL_PATH}" ]]
            generate_theme "" "${VYLE_CONFIG_HOME}/theme.ivy" ""
            generate_theme "_rgba" "${VYLE_CONFIG_HOME}/theme-rgba.ivy" "_rgba"
            ionice -c 3 nice -n 19 "${scrDir}/modules/ivyshell-helper.sh"
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
    [[ "${WallAddCustomPath}" == "none" ]] && unset WallAddCustomPath
    mapfile -d '' files < <(LC_ALL=C find "${wallSel}" "${WallAddCustomPath[@]}" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.jpeg" \) -print0 | sort -Vzf)
    menu() {
        for indx in "${files[@]}"; do
            name="${indx##*/}"
            thumb="${thumbDir}/${name%.*}.sloc"
            [[ ! -f "$thumb" ]] && "${scrDir}/swwwallcache.sh" -f "$indx"
            printf "%s\x00icon\x1f%s\n" "$name" "$thumb" 
        done
    }
    choice=$(menu | rofi -dmenu -i -p "Wallpaper" -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofiConf}" -select "${wallSet##*/}")
    [[ -z "$choice" ]] && exit 0
    wallSelTui -i "${wallSel}/$choice"
}

wall_control() {
    local wall wall_i wallCheck wallpapers wallTotal wallFinal swwwTrans
    wallCheck="${1:-}"
    wall="${wallSet##*/}"

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

