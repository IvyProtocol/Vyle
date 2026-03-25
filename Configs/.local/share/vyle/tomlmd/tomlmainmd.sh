#|--/ /+-------------------------+--/ /|#
#|-/ /-| IDE Configuration File |-/ /-|#
#|/ /--+-------------------------+/ /--|#
source "${VYLE_DATA_HOME}/staterc.conf"

#  █░█ █▄█ █░░ █▀▀ 
#  ▀▄▀ ░█░ █▄▄ ██▄  

#// plLoader, sets custom placeholder for wallbash/ivy to work with .dcol and .ivy files.
#// Usage, add plLoader="example|example1|example2" as your custom placeholder.
#// Now you can use your own custom placeholder only by declaring it on your .dcol or .ivy.
#// Warning! This may not work for others if placeholder is different from the intended
plLoader="ivy|wallbash"

#// skipTemplate, specifies .ivy or .dcol template that should be excluded or skipped from procesing!
#// This allows you to selectively exclude certain template that exists in  while still processing others.
#// example:
skipTemplate=${VYLE_CONFIGURATION_SKIP_TEMPLATE[@]}

#// nProcCount, lets wallbash use the maximum or limited CPU utilization to process templates!
#// You can limit the core utilization by declaring the number of cores to be utilized.
#// Defaulted is '3', but $(nproc) can be used here. e.g., nProcCount=$(nproc).
nProcCount=$(nproc)

# █░█░█ ▄▀█ █░░ █░░ █▀█ ▄▀█ █▀█ █▀▀ █▀█
# ▀▄▀▄▀ █▀█ █▄▄ █▄▄ █▀▀ █▀█ █▀▀ ██▄ █▀▄

# Chosen Backend! SWWW
wallBackend="awww"

#// set the transition FPS while changing wallpaper.
wallFramerate=60

#// set the transition duration for swww while changing wallpaper.
wallTransDuration=0.4

#// set animation for swww while changing wallpaper.
wallAnimationPrevious="outer"
wallAnimationNext="grow"
wallAnimationTheme="grow"

# set transition-bezier for swww while changing wallpaper.
wallTransitionBezier=".43,1.19,.1,.4"

#// WallAddCustomPath, sets a custom user directories scanned for wallpapers.
#// add your wallpaper directories as - WallAddCustomPath=("/path/to/wall/dir1" "/path/to/wall/dir2")
#// setting a custom directory for wallDir would result in to cache wallpapers by /swwwallcache.sh!
#// example:
WallAddCustomPath=("${WALLPAPER_CONFIGURATION_CUSTOMPATH[@]}")

# █▀█ █▀█ █▀▀ █
# █▀▄ █▄█ █▀░ █

# rofiLauncher.sh configuration.
rofiLauncherFont="JetBrainsMono Nerd Font"
rofiLauncherScale=9
rofiLauncherStyle=1


# wbselecgen.sh configuration
rofiWallpaperFont="JetBrainsMono Nerd Font"
rofiWallpaperScale=9
rofiWallpaperColumn=4

# themeswitch.sh configuration.
rofiThemeFont="JetBrainsMono Nerd Font"
rofiThemeScale=9
rofiThemeColumn=2
rofiThemeStyle=2

# style-launcher.sh configuration.
rofiStyleScale=12

# wallbashtoggle.sh configuration
rofiWallbashFont="JetBrainsMono Nerd Font"
rofiWallbashScale=9

# █░░ █▀█ █▀▀ █▀█ █░█ ▀█▀
# █▄▄ █▄█ █▄█ █▄█ █▄█ ░█░

#// wlogoutStyle sets the style for logout menu
#// available styles - 1 (default) , 2
wlogoutStyle=2

# █▀▀ ▄▀█ █▀ ▀█▀ █▀▀ █▀▀ ▀█▀ █▀▀ █░█
# █▀░ █▀█ ▄█ ░█░ █▀░ ██▄ ░█░ █▄▄ █▀█

#// fetchIcon, sets the user directories scanned for finding fastfetch icons and randomizes. Default is to /home/iris/.config/fastfetch/icons!
fetchIcon="${XDG_CONFIG_HOME}/fastfetch/icons"

# █▄▄ █▀█ █ █▀  █░█ ▀█▀ █▄░█ █▀▀ █▀ █▀ █▀ ▀█▀ █░░ 
# █▄█ █▀▄ █ █▄█ █▀█ ░█░ █░▀█ ██▄ ▄█ ▄█ █▄ ░█░ █▄▄

#// brightnesscontrol.sh configuration, declarable according to user preference.
#// brightnessIconDir is string-type variable that needs directory for dunst to use icons.
#// brightnessStep is integer-type variable that is determined through 0 (true) and 1 (False).
#// brightnessNotify is integer-type, determined of 0 and 1.
brightnessIconDir="${XDG_CONFIG_HOME}/dunst/icons/vol"
brightnessStep=5
brightnessNotify=0

# █░█ █▀█ █░░ █░█ █▀▄▀█ █▀▀ █▀ ▀█▀ █░░ 
# ▀▄▀ █▄█ █▄▄ █▄█ █░▀░█ ██▄ █▄ ░█░ █▄▄

#// voluemcontrol.sh configuration, declarable according to user preference.
#// volumeStep is an integer-type variable to determine the steps. For example, volumeStep is defaultly set to 5.
#// volumeNotifyUpdateLevel & volumeNotifyMute, is an integer-type variable that suppress Notification-Popups determined through 0 (true) or {1 or greater (false)}.
volumeIconDir="${XDG_CONFIG_HOME}/dunst/icons/vol"
volumeStep=5
volumeNotifyUpdateLevel=0
volumeNotifyMute=0

# █▄░█ █▀█ ▀█▀ █ █▀▀ █ █▀▀ ▄▀█ ▀█▀ █ █▀█ █▄░█
# █░▀█ █▄█ ░█░ █ █▀░ █ █▄▄ █▀█ ░█░ █ █▄█ █░▀█
# dunstctl configuration
notificationFont="mononoki Nerd Font Bold"
notificationFontSize=10

# █░█ █▄█ █▀█ █▀█ █░░ ▄▀█ █▄░█ █▀▄
# █▀█ ░█░ █▀▀ █▀▄ █▄▄ █▀█ █░▀█ █▄▀

# Hyprland Configuration.
CONSOLE="kitty"
EDITOR="vscodium"
EXPLORER="dolphin"
BROWSER="firefox"
LOCK_SCREEN="hyprlock"
TASK_MANAGER="gnome-system-monitor"
CURSOR_THEME="Bibata-Modern-Ice"
CURSOR_SIZE=20

# █▀▀ ▀█▀ █▄▀
# █▄█ ░█░ █░█
# GTK Configuration
GTK_FONT_NAME="CaskaydiaCove Nerd Font Mono"
GTK_FONT_ANTIALIASING="rgba"
GTK_FONT_HINTING="slight"
GTK_FONT_SIZE=10.5
GTK_DOCUMENT_FONT="JetBrainsMono Nerd Font"
GTK_DOCUMENT_FONT_SIZE=10
GTK_MONOSPACE_FONT="CaskaydiaCove Nerd Font Mono"
GTK_MONOSPACE_FONT_SIZE=10

# █▀▀ ▀▄▀ ▀█▀ █▀█ ▄▀█
# ██▄ █░█ ░█░ █▀▄ █▀█

#// Exclusion, add exclusion to a variable that needs to be unset. Avoids conflicting variable and secures purity of globalcontrol.sh.
#// Makes the variable local only for ide.conf.
#// add the exclusions to unset the variable.
#// Do not let exclusion be defined empty. This will unload all the variable and immediately fail!
#// If an exclusion is declared, it would still be set to empty.
# exclusion="()"
