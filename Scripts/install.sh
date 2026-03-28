#!/usr/bin/env bash

scrDir="$(dirname "$(realpath "$0")")"
[[ -e "${scrDir}/globalfunction.sh" ]] && { source "${scrDir}/globalfunction.sh"; echo -e " :: Sourcing Global Function"; } || { echo -e " :: Global Function not found!"; exit 1; }
[[ "$EUID" -eq 0 ]] && { echo -e "${IndentError} This script should ${indentWarning} NOT ${indentReset} be executed as root!!"; exit 1; }

if grep -iqE '(ID|ID_LIKE)=.*(arch)' /etc/os-release >/dev/null 2>&1; then
  echo -e " :: ${indentOk} Arch Linux Detected."
  while true; do 
    prompt_timer 120 "${indentAction} Do you want to install anyway?"
    case "$PROMPT_INPUT" in
      [Yy]|[Yy]es)
        echo -e " :: ${indentNotice} Proceeding on Arch Linux by user confirmation."
        break
        ;;
      [Nn]|[Nn]o|*)
        echo -e " :: ${indentError} Aborting installation due to user preference. No changes were made to the system. ${exitCode0}" && exit 0
        ;;
    esac
done
fi

mkdir -p "${cloneDir}"
if [[ -d "${cloneDir}/cachyos-repo" || -d "${cloneDir}/${cachyRp}" ]]; then
  prompt_timer 120 "${indentAction} Would you like to delete ${cachyRp} directory?"
  case "$PROMPT_INPUT" in
    [Yy]|[Yy]es)
      echo -e " :: ${indentNotice} Deleting ${indentGreen} the repository."
      rm -rf "${cloneDir}/${cachyRp}" "${cloneDir}/cachyos-repo"
      ;;
    [Nn]|[Nn]o)
      prompt_timer 120 " :: ${indentNotice} Would you like to rather use the repository instead?"
      case "$PROMPT_INPUT" in
        [Yy])
          [[ -e "${cloneDir}/cachyos-repo/cachyos-repo.sh" ]] && "${cloneDir}/cachyos-repo/cachyos-repo.sh" || echo "${indentError} Something went ${indentWarning} wrong ${indentWarning} while deleting cachyos directory." | exit 1
          ;;
        [Nn]|*) echo -e " :: ${indentOk} Aborting deletion of cachyos-repo."
          ;;
      esac
      ;;
  esac
else
  prompt_timer 120 "${indentNotice} Would you like to get cachyos-repository?"
  case "${PROMPT_INPUT}" in
    [Yy]|[Yy]es)
      mkdir -p "${cloneDir}" && tar -xvf "${cloneDir}/${cachyRp}" -C "${cloneDir}"
      eval "${cloneDir}/cachyos-repo/cachyos-repo.sh" 
      [[ $? -eq 0 ]] && echo -e " :: ${indentOk} Repository has been ${indentGreen} installed to the system! "${exitCode0}"" || echo -e " :: ${indentError} failed to install "${indentGreen}"!"
      ;;
    [Nn]|[Nn]o|*)
      echo -e " :: ${indentReset} Aborting due to user preference. ${exitCode0}"
      ;;
  esac
fi

if command -v yay &>/dev/null || command -v yay-bin &>/dev/null; then
  echo -e " :: ${indentOk} yay is already installed onto the system. Skipping!"
else
  if [[ "${rpCheck}" -eq 1 ]]; then
    env_pkg -A pacman -- -S yay-bin
  else
    git clone --depth 1 "https://aur.archlinux.org/${aurRp}.git" "${cloneDir}/${aurRp}"
    makepkg -si --directory "${cloneDir}/${aurRp}" 
  fi

  [[ $? -eq 0 ]] && echo -e " :: ${indentOk} yay has been successfully installed!" || echo -e " :: ${indentError} yay has not been installed!"
  exit 1
fi

if [[ -e "${pkgsRp}" ]]; then
	"${pkgsRp}" --hyprland
else
	echo -e " :: ${indentError} Does ${pkgsRp} exist?" && exit 1
fi
prompt_timer 120 "${indentNotice} Would you like to get additional packagess?"
case "$PROMPT_INPUT" in
  [Yy]|[Yy]es)
    ${pkgRp} --extra
    echo -e " :: ${indentOk} All extra packages has been installed onto the system!"
    ;;
  [Nn]|[Nn]o|*)
    echo -e " :: "${indentOk}" Skipping!"
    ;;
esac
sddmtheme=0
prompt_timer 120 "${indentNotice} Would you also like to get SDDM theme?"
case "$PROMPT_INPUT" in
  [Yy]|[Yy]es)
    echo -e " :: ${indentAction} Proceeding installation of SDDM."
    "${pkgsRp}" --sddm
    sddmtheme=1
    ;;
  [Nn]|[Nn]o)
    echo -e " :: ${indentReset} Aborting theming for SDDM due to User's Request!"
    ;;
esac

[[ ! -d "${confDir}" ]] && mkdir -p "${confDir}"
if [[ ! -d "${configDir}" ]]; then
	echo -e " :: ${configDir} does not exist.... How are we going to proceed?" && exit 1
fi
confcheck="fastfetch kitty rofi swaync btop hypr ivy-shell Kvantum nwg-look qt6ct waybar wlogout dunst"
for conf in ${confcheck}; do
  confpath="${confDir}/${conf}"
  if [[ -d "${confpath}" ]]; then
    while true; do
      echo -e " :: ${indentInfo} Found ${indentYellow} ${conf} ${indentOrange} config found in ${confDir}"
      echo -e " :: ${indentNotice} If you choose 'No', then they will be deleted! Make sure to backup!"
      prompt_timer 120 "${indentAction} Do you want to backup ${indentBlue} ${conf} ${indentReset}?"
      case "$PROMPT_INPUT" in
        [Yy]|[Yy]es)
          backupConf="${homDir}/.backup"
          mkdir -p "${backupConf}"
          mv "${confpath}" "${backupConf}/${conf}-$(timestamp_dirname "backup")"
          echo -e " :: ${indentOk} Backed up ${conf} to ${backupconf}"
          backup=1
          break
          ;;
        [Nn]|[Nn]o)
          rm -rf "${confDir}"
          break
          ;;
        *)
          echo -e " :: ${indentWarning} - Invalid choice. Please enter Y or N."
          continue 
          ;;
      esac
    done
    continue
  else
    echo -e "Populating ${confDir}"
    "${scrDir}/dircaller.sh" --all "${homDir}" 2>&1
    break
  fi
  if [[ "${backup}" -eq 1 ]]; then
    echo -e "Populating ${confDir}"
    "${scrDir}/dircaller.sh" --all "${homDir}" 2>&1
    break
  fi
done

[[ -e "${sourceDir}/Sweet-cursors.tar.xz" ]] && tar -xvf "${sourceDir}/Sweet-cursors.tar.xz" -C "${homDir}/.icons" 
if [[ ! -e "${confDir}/gtk-4.0/assets" || ! -e "${confDir}/gtk-4.0/gtk-dark.css" ]]; then
  sudo ln -sf /usr/share/themes/adw-gtk3/assets "${confDir}/gtk-4.0/assets"
  sudo ln -sf /usr/share/themes/adw-gtk3/gtk-4.0/gtk-dark.css "${confDir}/gtk-4.0/gtk-dark.css"
  echo -e " :: ${indentOk} GTK Symlinks re-initialized!"
fi
if [[ ! -e "${confDir}/waybar/style.css" || ! -e "${confDir}/waybar/config" ]]; then
  ln -sf ${confDir}/waybar/Styles/\[BOT\]\ HyDE.css "${confDir}/waybar/style.css"
  ln -sf ${confDir}/waybar/Styles/Configs/\[TOP\]\ HyDE-05.jsonc "${confDir}/waybar/config"
  echo -e " :: ${indentOk} Waybar Configuration Symlinks reinstated!"
fi
if env_pkg -- -Q "nvim" &>/dev/null; then
  echo -e " :: ${indentInfo} By default, the installation comes with neovim preinstalled."
  prompt_timer 20 "${indentAction} Would you like to make neovim the default?"
  case "$PROMPT_INPUT" in 
    Y|y)
      update_editor "nvim"
      ;;
    N|n|*)
      if env_pkg -- -Q "vim" &>/dev/null; then
        prompt_timer 20 "${indentOk} How about vim?"
        [[ $PROMPT_INPUT == "y" ]] && update_editor "vim" || update_editor "nano"
      fi
      ;;
  esac
fi

if [[ "${sddmtheme}" -eq 1 ]]; then
  [[ -f "${sourceDir}/SDDM-Silent.tar.gz" ]] || echo -e "SDDM-Silent does not exist!"
  sudo chmod -R 775 /usr/share/sddm/theme/ 
  tar -xvf "${sourceDir}/SDDM-Silent.tar.gz" -C "${cloneDir}"
  sudo cp "${cloneDir}/silent" "/usr/share/sddm/themes/"
  sudo cp "${cloneDir}/../state/ivy-shell/sddm/sddm.conf" "/etc/sddm.conf"
fi

cShell="$(getent passwd "$USER" | cut -d: -f7)"

if [[ "${cShell}" == "/usr/bin/fish" ]]; then
  echo -e : :: "${indentOk} Shell is already set to ${cShell}"
else
  prompt_timer 120 "${indentAction} Would you like to switch to fish?"
  case $PROMPT_INPUT in 
    Y|y)
      set +e
      echo -e " :: ${indentNotice} Switching the shell to fish."
      chsh -s /usr/bin/fish 2>&1

      [[ $? -eq 0 ]] && echo -e " :: ${indentOk} Changed from ${cShell} to /usr/bin/fish!"
      ;;
    N|n|*)
      echo -e " :: ${IndentOk} Skipping..."
  esac
fi

[[ ! -e "${localDir}/swwwallcache.sh" ]] && { echo -e " :: swwwallcache.sh does not exist."; exit 1; }
"${localDir}/swwwallcache.sh" -w "${confDir}/vyle/theme/"
xdg-user-dirs-update && sudo systemctl enable sddm 2>&1

echo -e " :: The installation has been finished!"
echo -e "${indentAction} It is not recommended ot use newly installed or upgraded dotfile without rebooting the system."
prompt_timer 120 "${indentAction} Would you like to reboot?"
case "$PROMPT_INPUT" in
  Y|y)
    echo " :: ${indentOk} Rebooting the system!"
    systemctl reboot
    ;;
  [Nn]|*)
    echo -e "${indentOk} The system will not reboot."
    exit 0
    ;;
esac
