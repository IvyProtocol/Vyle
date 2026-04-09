#!/usr/bin/env bash
scrDir=$(dirname "$(realpath "$0")")

if [[ ! -f "${scrDir}/globalcontrol.sh" ]]; then
    rasiScr="$HOME/.config/rofi/shared/config-clipboard.rasi"
else
    source "${scrDir}/globalcontrol.sh"
    rasiScr="${rasiDir}/config-clipboard.rasi"
fi

kbcus1="Control-Delete"
kbcus2="Alt-Delete"

if ! env_pkg -- -Q "rofi"; then
    notify -m 1 -p " Is rofi installed? exit-code 1."
    exit 1
fi

while true; do
    select=$(
        rofi -i -dmenu \
            -kb-custom-1 "$kbcus1" \
            -kb-custom-2 "$kbcus2" \
            -config "${rasiScr}" < <(cliphist list) 
    )

    case "$?" in
        1)
            exit
            ;;
        0)
            case "$select" in
                "")
                    continue
                    ;;
                *)
                    cliphist decode <<<"$select" | wl-copy
                    exit
                    ;;
            esac
            ;;
        10)
            cliphist delete <<<"$select"
            ;;
        11)
            cliphist wipe
            ;;
    esac
done

