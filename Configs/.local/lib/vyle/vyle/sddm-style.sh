#!/usr/bin/env bash

IFS=$'\n\t'

# Define directories
scrDir=$(dirname "$(realpath "$0")")
source "$scrDir/globalcontrol.sh"

wlDir="/usr/share/sddm/themes/silent/themes"
wcDir="/usr/share/sddm/themes/silent/configs/"
rasiDir="${rasiDir}/config-waybar.rasi"

apply_config() {
    ln -sf "${wlDir}/$1" "$wcDir/default.conf"
    notify-send -a "SDDM" -r 2 -t 2200 "Style Applied"
}

main() {
    local sddmLayout="${1}"
    current_target=$(readlink -f "$wcDir")
    current_name=$(basename "$current_target")

    mapfile -t options < <(
        find -L "${wlDir}" -maxdepth 1 -type f -printf '%f\n' | sort -V
    )

    default_row=0
    MARKER="👉"
    for i in "${!options[@]}"; do
        if [[ "${options[i]}" == "$current_name" ]]; then
            options[i]="$MARKER ${options[i]}"
            default_row=$i
            break
        fi
    done

    choice=$(printf '%s\n' "${options[@]}" \
        | rofi -i -dmenu \
               -config "$rasiDir" \
               -selected-row "$default_row"
    )

    echo "${choice}"

    [[ -z "$choice" ]] && { echo "No option selected. Exiting."; exit 0; }

    choice=${choice# $MARKER}

    case "$choice" in
        *)
            apply_config "$choice"
            ;;
    esac
}

if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

main
