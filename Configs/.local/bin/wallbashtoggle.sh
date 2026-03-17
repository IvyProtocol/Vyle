#!/usr/bin/env bash
set -eo pipefail
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

rasiPath="${rasiDir}/shell.rasi"

apply_config() {
    [[ $1 == "auto" ]] && wallIde=0
    [[ $1 == "dark" ]] && wallIde=1
    [[ $1 == "light" ]] && wallIde=2
    [[ $1 == "theme" ]] && wallIde=3 

    [[ -n "${enableWallIde}" ]] && setConf "enableWallIde" "${wallIde}" "${VYLE_STATE_HOME}/staterc" || setConf "enableWallIde" "0" "${VYLE_STATE_HOME}/staterc"
    notify -m 2 -i "theme_engine" -p "Theme Mode: $1" -s "${dunstDir}/icons/hyprdots.svg" -t 900 -a "t1"
    [[ ! -e "${scrDir}/wallbash.sh" ]] && exit 1
    if [[ "${wallIde}" -eq 3 ]]; then
        setConf "VYLE_THEME|enableWallIde" "${VYLE_RESERVED_THEME}|3" "${VYLE_STATE_HOME}/staterc"
        [[ -f "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/theme.dcol" ]] && cp "${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}/theme.dcol" "${VYLE_CONFIG_HOME}/main/ivygen.dcol" 
        sed -i 's|^[[:space:]]*source[[:space:]]*=[[:space:]]*./themes/wallbash-ide.conf|#source = ./themes/wallbash-ide.conf|' "${XDG_CONFIG_HOME}/hypr/hyprland.conf"
        "${scrDir}/modules/ivyshell-helper.sh"
        exit 0
    else
        [[ "${VYLE_THEME}" != "Wallbash-Ivy" ]] && setConf "VYLE_THEME" "Wallbash-Ivy" "${VYLE_STATE_HOME}/staterc" &
        sed -i 's|^#[[:space:]]*source[[:space:]]*=[[:space:]]*./themes/wallbash-ide.conf|source = ./themes/wallbash-ide.conf|' "${XDG_CONFIG_HOME}/hypr/hyprland.conf"
        "${scrDir}/wallbash.sh" "${wallSet}" --"${1}"
    fi

    if [[ -z "${wallSet}" && -x "${scrDir}/swwwallswitch.sh" ]]; then
        rnSel=$(find "${wallDir}" -maxpath 1 -type f | shuf -n 1)
        "${scrDir}/swwwallswitch.sh" -i "${rnSel}"
    fi
}

rofi_wallbash() {
    if [[ -z "${rofiWallbashScale}" || "${rofiWallbashScale}" -eq 0 ]]; then
        rofiWallbashScale=10
    fi

    r_scale="configuration {font: \"JetBrainsMono Nerd Font ${rofiWallbashScale}\";}"
    elem_border=$(( hypr_border * 4 ))
    r_override="window{border-radius:${elem_border}px;} element{border-radius:${elem_border}px;}"

    wallbashModes=(theme auto dark light) 
    choice=$(parallel echo {} ::: "${wallbashModes[@]}" \
        | rofi -i -dmenu -theme-str "${r_scale}" \
        -theme-str "${r_override}" -config "$rasiPath" \
        -select "${wallbashModes[$(($enableWallIde + 1))]}" )

    [[ -z "$choice" ]] && { echo "No option selected. Exiting."; exit 0; }
    sleep 0.7
    apply_config "$choice"
}

[[ -z "$1" ]] && rofi_wallbash || apply_config "$1"
