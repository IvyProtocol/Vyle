help_function() {
  cat <<EOF
Vyle-Project: ${0##*/} command-line wallpaper handler.
Usage:
  ${0##*/} [flags]
Available Flags:
  -n | --next     Switch to the next wallpaper
  -p | --prev     Switch to the previous wallpaper
  -t | --multi-select   Use other flags
  -r | --random   Switch to a random wallpaper
  -h | --help     ${0##*/} executes --help
Tips: 
  Use ${0##*/} [flag] --help for more information about a command/flag.
EOF
}


