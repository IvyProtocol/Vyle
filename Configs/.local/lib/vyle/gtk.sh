#!/usr/bin/env bash

$HOME/.local/lib/vyle/reload_waybar.sh &

(
  pkill -SIGUSR1 nautilus || true
  pkill -SIGUSR1 file-roller || true
  pkill -f -SIGUSR1 gnome-system-monitor || true
  pkill -SIGUSR1 gnome-disks || true
  nautilus --quit
  pkill -SIGUSR1 gnome-sound-recorder || true
) &>/dev/null &
