#!/usr/bin/env bash
$XDG_CONFIG_HOME/hypr/scripts/toggle-waybar.sh

(
    pkill -SIGUSR1 nautilus || true
    pkill -SIGUSR1 file-roller || true
    pkill -f -SIGUSR1 gnome-system-monitor || true
    pkill -SIGUSR1 gnome-disks || true
    nautilus --quit
    pkill -SIGUSR1 gnome-sound-recorder || true
) &>/dev/null


