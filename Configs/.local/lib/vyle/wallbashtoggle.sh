#!/usr/bin/env bash
set -eo pipefail
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

rasiPath="${rasiDir}/wallbash.rasi"

apply_config() {
    local arg="$1"

    case "$arg" in
    auto) wallIde=0 ;;
    dark) wallIde=1 ;;
    light) wallIde=2 ;;
    theme) wallIde=3 ;;
    *)
        echo "Invalid argument: available - auto :: dark :: light :: theme"
        exit 1
        ;;
    esac

    [[ -n "${WALLBASH_MODE}" ]] && setConf "WALLBASH_MODE" "${wallIde}" "${VYLE_STATE_HOME}/staterc" || setConf "WALLBASH_MODE" "0" "${VYLE_STATE_HOME}/staterc"
    notify -m 2 -i "theme_engine" -p "Theme Mode: $arg" -s "${dunstDir}/icons/hyprdots.svg" -t 900 -a "t1"
    [[ ! -e "${scrDir}/wallbash.sh" ]] && exit 1

    export VYLE_CONFIG_HOME=$VYLE_CONFIG_HOME
    export HYDE_TMQ_PROC="$VYLE_CONFIGURATION_CORE"
    export HYDE_TMQ_NO_ATOMIC=1
    export HYDE_TMQ_IGNORE_UNBOUND=1
    export HYDE_TMQ_IGNORE_TEMPLATES="${VYLE_CONFIGURATION_SKIP_TEMPLATE}"

    if [[ "${wallIde}" -eq 3 ]]; then
        setConf "VYLE_THEME|WALLBASH_MODE" "${VYLE_RESERVED_THEME}|3" "${VYLE_STATE_HOME}/staterc"
        sed -i 's|^[[:space:]]*source[[:space:]]*=[[:space:]]* \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|#source = \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|' "${VYLE_DATA_HOME}/hypr/dynamic.conf"
        read -r hashMech <<<"$(md5sum "${VYLE_CURRENT_IMAGE}" | awk '{print $1}')"

        if [[ ! -e "${VYLE_CACHE_HOME}/shell/auto/${hashMech}.dcol" ]]; then
            "${scrDir}/swwwallcache.sh" -w "${VYLE_CURRENT_IMAGE}"
        fi
        VYLE_DCOL_PATH="$VYLE_CACHE_HOME/shell/auto/$hashMech.dcol"
        [[ -e "${VYLE_DCOL_PATH}" ]]

        generate_theme "" ""
        generate_theme "_rgba" "_rgba"
        POPULATE=("${VYLE_CONFIG_HOME}/theme/${VYLE_RESERVED_THEME}" "${VYLE_CONFIG_HOME}/Wall-Ways")

        source "${scrDir}/tmq.write.sh" \
            --file "${POPULATE[@]}"
    else
        [[ "${VYLE_THEME}" != "Wallbash-Ivy" ]] && setConf "VYLE_THEME" "Wallbash-Ivy" "${VYLE_STATE_HOME}/staterc" &
        sed -i 's|^#[[:space:]]*source[[:space:]]*=[[:space:]]* \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|source = \$XDG_CONFIG_HOME/hypr/themes/wallbash.conf|' "${VYLE_DATA_HOME}/hypr/dynamic.conf"
        read -r hashMech <<<"$(md5sum "${VYLE_CURRENT_IMAGE}" | awk '{print $1}')"

        if [[ ! -e "${VYLE_CACHE_HOME}/shell/${arg}/${hashMech}.dcol" ]]; then
            "${scrDir}/swwwallcache.sh" -w "${VYLE_CURRENT_IMAGE}"
        fi
        VYLE_DCOL_PATH="${VYLE_CACHE_HOME}/shell/${arg}/${hashMech}.dcol"
        [[ -e "${VYLE_DCOL_PATH}" ]]

        generate_theme "" ""
        generate_theme "_rgba" "_rgba"

        POPULATE=("${VYLE_CONFIG_HOME}/Wall-Dcol" "${VYLE_CONFIG_HOME}/Wall-Ways")

        source "${scrDir}/tmq.write.sh" \
            --file "${POPULATE[@]}"
    fi

    if [[ -z "${VYLE_CURRENT_IMAGE}" && -x "${scrDir}/swwwallswitch.sh" ]]; then
        rnSel=$(find "${VYLE_WALLPAPER_DIRECTORY}" -maxpath 1 -type f | shuf -n 1)
        "${scrDir}/swwwallswitch.sh" -i "${rnSel}"
    fi
}

rofi_wallbash() {
    if [[ -z "${ROFI_WALLBASH_SCALE}" || "${ROFI_WALLBASH_SCALE}" -eq 0 ]]; then
        ROFI_WALLBASH_SCALE=10
    fi

    r_scale="configuration {font: \"${ROFI_WALLBASH_FONT} ${ROFI_WALLBASH_SCALE}\";}"
    elem_border=$((hypr_border * 4))
    r_override="window{border-radius:${elem_border}px;} element{border-radius:${elem_border}px;}"

    wallbashModes=(theme auto dark light)
    choice=$(parallel echo {} ::: "${wallbashModes[@]}" |
        rofi -i -dmenu -theme-str "${r_scale}" \
            -theme-str "${r_override}" -config "$rasiPath" \
            -select "${wallbashModes[$(($WALLBASH_MODE + 1))]}")

    [[ -z "$choice" ]] && {
        echo "No option selected. Exiting."
        exit 0
    }
    apply_config "$choice"
}

[[ -z "$1" ]] && rofi_wallbash || apply_config "$1"
