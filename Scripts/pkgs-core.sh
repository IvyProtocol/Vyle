#!/usr/bin/env bash
set -euo pipefail

hyprland=( 
  base
  base-devel
  efibootmgr
  thermald
  os-prober
  tuned-ppd
  pacman-contrib
  cpupower
  brightnessctl
  downgrade
  
  hyprland
  hyprlock
  hypridle
  sddm
  waybar
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  xdg-user-dirs
  polkit-gnome
  wlogout
  kxmlgui5
  adw-gtk-theme

  bluez-utils
  bluetui
  network-manager-applet
  wireless_tools

  alsa-utils
  pipewire-alsa
  pipewire-pulse
  parallel
  gst-plugin-pipewire
  mpd
  mpc
  ncmpcpp
  pavucontrol
  pamixer

  inotify-tools
  jq
  file-roller
  ncdu
  unzip
  udiskie
  xdotool
  wl-clip-persist
  cliphist
  nvim
  imagemagick
  qt6-imageformats
  qt6-wayland
  smartmontools
  swww

  fish
  starship
  fastfetch

  firefox
  dolphin
  kitty
  rofi
  loupe
  kvantum
  qt6ct-kde
  kde-cli-tools
  nwg-look
  gnome-disk-utility
  gnome-system-monitor
  dunst

  ttf-cascadia-code-nerd
  ttf-fira-mono
  ttf-jetbrains-mono-nerd
  ttf-segoe-ui-variable
  ttf-times-new-roman
  noto-fonts-cjk
  ttf-mononoki-nerd
  tela-circle-icon-theme-dracula
  bibata-cursor-theme
)

extra=(
  gnome-sound-recorder
  btop
  cava
  wl-screenrec
  vscodium
  vscodium-marketplace
  spotify
)

driver=(
  vulkan-intel
  xf86-video-ati
  acpi
  acpi_call
  acpid
  tp_smapi
  intel-media-driver
  intel-ucode
  libva-intel-driver
  libva-utils
  mesa-utils
  vulkan-headers
)

sddm=(
  qt6-svg
  qt6-virtualkeyboard
  qt6-multimedia-ffmpeg
)

scrDir="$(dirname "$(realpath "$0")")"
source "$scrDir/globalfunction.sh"
var="${1:-}"
 
case $var in
  --hyprland)
    env_pkg -- -S "${hyprland[@]}"
    sudo pacman -U "${sourceDir}/vyle-1.0.1-1-any.pkg.tar.zst"
    ;;
  --extra)
    env_pkg -- -S "${extra[@]}"
    ;;
  --driver)
    env_pkg -- -S "${driver[@]}"
    ;;
  --sddm)
    env_pkg -- -S "${sddm[@]}"
    ;;
  *|"")
    exit 0
    ;;
esac

