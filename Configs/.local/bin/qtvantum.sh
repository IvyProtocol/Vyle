#!/usr/bin/env bash

a_ws=$(hyprctl -j activeworkspace | jq '.id')
dpid=$(hyprctl -j clients | jq --arg wid "$a_ws" '.[] | select(.workspace.id == ($wid | tonumber)) | select(.class == "org.kde.dolphin") | .pid')
if [ ! -z ${dpid} ] ; then
    hyprctl dispatch closewindow pid:${dpid}
    hyprctl dispatch exec dolphin &
fi

if pgrep -f "polkit-gnome-authentication-agent-1" > /dev/null; then
    # Kill existing agent properly
    pkill -f "polkit-gnome-authentication-agent-1"
fi
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &

if pgrep -f "xdg-desktop-portal-gtk" > /dev/null; then
    pkill -f "xdg-desktop-portal-gtk"
fi
    /usr/lib/xdg-desktop-portal-gtk >/dev/null 2>&1 &

if pgrep -f "xdg-desktop-portal-hyprland" > /dev/null; then
    pkill -f "xdg-desktop-portal-hyprland"
fi
    /usr/lib/xdg-desktop-portal-hyprland >/dev/null 2>&1 &

