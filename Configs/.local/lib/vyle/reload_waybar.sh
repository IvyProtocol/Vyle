#!/usr/bin/env bash

if pgrep -x "waybar" > /dev/null; then
    {
        pkill waybar &&
        waybar & disown 
    } >/dev/null 2>&1
else
    {
        waybar
    } >/dev/null 2>&1
fi & disown
