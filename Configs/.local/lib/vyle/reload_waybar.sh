#!/usr/bin/env bash

if pgrep -x "waybar" >/dev/null; then
  {
    pkill waybar
    waybar &
    disown
  }
else
  {
    waybar
  }
fi >/dev/null 2>&1
