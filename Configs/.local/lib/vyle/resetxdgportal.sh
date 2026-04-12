#!/usr/bin/env bash

a_ws=$(hyprctl -j activeworkspace | jq '.id')
dpid=$(hyprctl -j clients | jq --arg wid "$a_ws" '.[] | select(.workspace.id == ($wid | tonumber)) | select(.class == "org.kde.dolphin") | .pid')
if [ ! -z ${dpid} ]; then
  hyprctl dispatch closewindow pid:${dpid}
  hyprctl dispatch exec dolphin &
fi

polkit=(
  # GTK (Arch, Fedora)
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
  "/usr/lib/xdg-desktop-poral-gtk"
  "/usr/libexec/polkit-gnome-authentication-agent-1"
  "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
  "/usr/lib/polkit-gnome-authentication-agent-1"
  "/usr/bin/polkit-gnome-authentication-agent-1"
)

for i in "${!polkit[@]}"; do
  polkit_agent="${polkit[i]##*/}"

  if pgrep -f "${polkit_agent}" >/dev/null 2>&1; then
    pkill -f "${polkit_agent}"
  fi

  if [ -x "${polkit[i]}" ] && [ -e "${polkit[i]}" ] && [ ! -d "${polkit[i]}" ]; then
    echo "Found ${polkit[i]} Executing...." >&2
    "${polkit[i]}" >/dev/null 2>&1 &
    disown
  fi
done
