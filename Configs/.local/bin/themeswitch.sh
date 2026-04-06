#!/usr/bin/env bash
set -eo pipefail

scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"

lockFile="${XDG_RUNTIME_DIR}/${0##*/}.lock"
if [ -e "${lockFile}" ]; then
    cat <<EOF
Error: Another instance of ${0##*/} is running.
If you are sure that no other instance of ${0##*/} running, then remove the lock file:
    $lockFile
EOF
    notify-send -a "t2" -r 91190 -t 800 -i "${dunstDir}/icons/hyprdots.svg" "Vyle" "Another instance of ${0##*/} is running."
    exit 0
fi

touch "${lockFile}"
trap 'rm -f ${lockFile}' EXIT

show_theme_status() {
    cat <<EOF
 :: Current theme: $VYLE_RESERVED_THEME
 :: Cursor theme: $CURSOR_THEME
 :: Cursor size: $CURSOR_SIZE
 :: Terminal: $CONSOLE
 :: Font: $GTK_FONT_NAME
 :: Font size: $GTK_FONT_SIZE
 :: Document font: $GTK_DOCUMENT_FONT
 :: Document font size: $GTK_DOCUMENT_FONT_SIZE
 :: Monospace font: $GTK_MONOSPACE_FONT
 :: Monospace font size: $GTK_MONOSPACE_FONT_SIZE
 ::
 :: Selected theme: $thmChsh
 :: Wallpaper: ${thmImg##*/}
 :: Wallpaper Backend: $wallBackend
 :: Framerate: ${wallFramerate}
 :: Duration: ${wallTransDuration}
 :: Bezier: ${wallTransitionBezier}
 :: Animation: {
 ::    Transition Previous: ${wallAnimationPrevious}
 ::    Transition Next: ${wallAnimationNext}
 ::    Transition Theme: ${wallAnimationTheme}
 :: }
 :: Custom Paths: [${wallAddCustomPath}]
 ::
EOF
}

show_help_status() {
    cat << EOF
 :: Vyle-Project's Theme-Switcher
 :: 
 :: Usage: ${0##*/} [flags]
 ::
 :: Available Flags:
 ::     -n | --next     Switch to the next theme.
 ::     -p | --prev     Switch to the previous theme.
 ::     -t | --tui      Requires an argument. 
 ::                         Example: ${0##*/} -t Decay-Green
 ::        | --select   Select wallpaper from rofi
 ::     -h | --help     Help Menu
 ::
EOF
}

themeDir="${VYLE_CONFIG_HOME}/theme"
rofiConf="${rasiDir}/selector.rasi"

themeSelTui() {
    thmChsh="${1}"
    thmImg="$(<"${themeDir}/${thmChsh}/wallpapers/.wallbash-main")"
    if [[ -n "${thmImg}" ]]; then
        show_theme_status &
        if [[ "${VYLE_RESERVED_THEME}" != "${thmChsh}" ]]; then
            setConf "VYLE_RESERVED_THEME" "${thmChsh}" "${VYLE_STATE_HOME}/staterc" 
        fi  
        if [[ "${wallDir}" != "${themeDir}/${thmChsh}/wallpapers" ]]; then
            echo " :: Theme Control - Theme '${thmChsh}' :: Wallpaper '${thmImg}' :: DcolMode '${enableWallIde}' --> '${XDG_CONFIG_HOME}'" 
            notify -m 2 -i "theme_engine" -p "${thmChsh}" -s "${VYLE_CACHE_HOME}/cache/thumb/$(fl_wallpaper -t "${thmImg}" -f 1).sloc" -t 1100 -a "t1"
            setConf "wallDir" "${themeDir}/${thmChsh}/wallpapers" "${VYLE_STATE_HOME}/staterc"
        else
            echo -e " :: Theme Control - Skipped populating $thmChsh -> ${XDG_CONFIG_HOME}"
            exit 0
        fi
        if [[ "${enableWallIde}" -eq 3 ]]; then
            if [[ "${VYLE_THEME}" != "${thmChsh}" ]]; then
                setConf "VYLE_THEME" "${thmChsh}" "${VYLE_STATE_HOME}/staterc"
            fi 
            sed -Ei 's|^[[:space:]]*source[[:space:]]*=[[:space:]]*./themes/wallbash-ide.conf|#source = ./themes/wallbash-ide.conf|' "${XDG_CONFIG_HOME}/hypr/hyprland.conf"
        else
            "${scrDir}/tmq.write.sh" "${themeDir}/${thmChsh}/hypr.theme"
             sed -Ei 's|^#[[:space:]]*source[[:space:]]*=[[:space:]]*./themes/wallbash-ide.conf|source = ./themes/wallbash-ide.conf|' "${XDG_CONFIG_HOME}/hypr/hyprland.conf" 
        fi
        [[ ! -e "${scrDir}/swwwallswitch.sh" ]] && { notify -m 1 -p "Does swwwallswitch.sh exist?" -s "${dunstDir}/icons/hyprdots.svg" -u critical; return 1; }
        "${scrDir}/swwwallswitch.sh" -t -i "${thmImg}" -w --swww-t -n 1 -r 1 
        echo -e " :: Theme Control - Populated successfully ${thmChsh} -> ${XDG_CONFIG_HOME}" &
    fi
}

thmSelEnv() {
    if [[ -z "${rofiThemeScale}" || "${rofiThemeScale}" -eq 0 ]]; then
        rofiThemeScale=10
    fi
    r_scale="configuration {font : \"${rofiThemeFont} ${rofiThemeScale}\";}"
    mon_x_res=$(( mon_res * 100 / mon_scale ))
    elem_border=$(( hypr_border * 3 ))
    icon_border=$(( elem_border - 5 ))
    local indx themes wallSet thumbDir thmExtn thmWall stripWall

    case "${rofiThemeStyle}" in
        2)
            elm_width=$(( (20 + 12 ) * rofiThemeScale * 2 ))
            max_avail=$(( mon_x_res - ( 4 * rofiThemeScale) ))
            if [[ -z "$rofiThemeColumn" || ! "$rofiThemeColumn" =~ ^[0-9]+$ || "$rofiThemeColumn" -eq 0 ]]; then
                rofiThemeColumn=$(( max_avail / elm_width ))
            fi
            r_override="window{width:100%;background-color:#00000003;} listview{columns:${rofiThemeColumn};} element{border-radius:${elem_border}px;background-color:@main-bg;} element-icon{size:20em;border-radius:${icon_border}px 0px 0px ${icon_border}px;}"
            thmExtn="quad"
            thumbDir="${VYLE_CACHE_HOME}/cache/quad"
            ;;
        1|*)
            elm_width=$(( (23 + 12 + 1) * rofiThemeScale * 2 ))
            max_avail=$(( mon_x_res - (4 * rofiThemeScale) ))
            if [[ -z "$rofiThemeColumn" || ! "$rofiThemeColumn" =~ ^[0-9]+$ || "$rofiThemeColumn" -eq 0 ]]; then
                rofiThemeColumn=$(( max_avail / elm_width ))
            fi
            r_override="window{width:100%;} listview{columns:${rofiThemeColumn};} element{border-radius:${elem_border}px;padding:0.5em;} element-icon{size:23em;border-radius:${icon_border}px;}"
            thmExtn="sloc"
            thumbDir="${VYLE_CACHE_HOME}/cache/thumb"
            ;;
    esac
    mapfile -t themes < <(LC_ALL=C find "${themeDir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -Vf)
    menu() {
        for indx in "${themes[@]}"; do
            wallSet="${themeDir}/${indx}/wall.set"
            symUpdate=0
                if [[ ! -e "${themeDir}/${indx}/wallpapers/.wallbash-main" ]]; then
                    thmWall=$(find "${themeDir}/${indx}/wallpapers" -type f ! -name '.*' | sort -V | head -n 1 | tee -a "${themeDir}/${indx}/wallpapers/.wallbash-main")
                else
                    thmWall="$(<"${themeDir}/${indx}/wallpapers/.wallbash-main")"
                fi
                thmWall="$(fl_wallpaper -t "${thmWall}" -f 1).${thmExtn}"

                relpath="$(readlink -f "${wallSet}" 2>/dev/null || true)"
                stripPath="${relpath##*.}"

                if [[ ! -L "${wallSet}" || -L "${wallSet}" && ! -e "${wallSet}" || "${stripPath}" != "${thmExtn}" || -z "${relpath}"  ]]; then
                    echo -e " :: fixing symlink - ${thumbDir}/${thmWall} -> ${wallSet}" >&2
                    ln -fs "${thumbDir}/${thmWall}" "${wallSet}"
                fi

            printf "%s\x00icon\x1f%s\n" "${indx}" "${wallSet}"
        done
    }
    choice=$(menu | rofi -dmenu -i -p "ThemeControl" -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofiConf}" -select "${VYLE_RESERVED_THEME}")
    [[ -z "$choice" ]] && exit 0
    themeSelTui "$choice"
}

theme_control() {
    local thm_i thmCheck thmFlags themes thmTotal thmFinal
    thmCheck="${1:-}"

    [[ -n "${VYLE_RESERVED_THEME}" ]] || return 1
    mapfile -t themes < <(LC_ALL=C find "${themeDir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -Vf )
    thm_i=-1
    for i in "${!themes[@]}"; do
        [[ "${themes[$i]}" == "${VYLE_RESERVED_THEME}" ]] && thm_i=$i
    done

    thmTotal="${#themes[@]}"
    case "${thmCheck}" in
     --p) idx=$(( (thm_i - 1 + thmTotal) % thmTotal )) ;;
     --n) idx=$(( (thm_i + 1) % thmTotal )) ;;
     *)
         return 1 
         ;;
    esac
    themeSelTui "${themes[$idx]}"
}

case "${1}" in
    -n | --next)
        theme_control --n  
        ;;
    -p | --prev)
        theme_control --p
        ;;
    -t | -tui)
        themeSelTui "$2"
        ;;
    -h | --help)
        show_help_status 
        ;;
    * | --select)
        thmSelEnv
        ;;
esac 


