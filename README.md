<div align="center">

![banner](Source/assets/irgen.gif)

A personal Hyprland-based desktop configuration with ivy-shell (Wallbash Fork from [HyDE](https://github.com/HyDE-Project/HyDE))

</div>

---

# ⚠️ Read First

This repository is maintained mainly for personal and prerequisite use.
Since it actively evolves, screenshots may become outdated. If you are looking out for wallpapers, then you may head toward [REPO](https://github.com/Namelessmode/Iricalgen-wbshow.git). This repository may be deprecated in the future.

## Installation
To install, clone this repository to any directory:

```
sudo pacman -S --needed git base-devel
git clone --depth 1 https://github.com/IvyProtocol/IDE.git ~/IDE
cd ~/IDE/Scripts/
./install.sh
```

> [!WARNING]
> The install script will create backup and overwrite files in ~/.config, ~/.local and ~/.icons. Be cautious, we are not responsible.

Please reboot the system after the step has been taken and takes you to SDDM login screen for the first time.

## Repository Layout

```text
tree VyLE                                                                         23:13 
VyLE/ <-------- $(rpDir)
├── Configs <--- Main Configuration
├── LICENSE
├── README.md
├── Scripts
│   ├── dircaller.sh
│   ├── globalfunction.sh
│   ├── install.sh
│   └── pkgs-core.sh
└── Source < ----- Extra Sources
    ├── assets
    │   └── irgen.gif
    ├── Code_Wallbash.vsix
    ├── Icon_Vivid-Glassy-Dark.tar.gz
    └── Sweet-cursors.tar.xz
```

# Credits
This repository is inspired by many projects, most notably:

- HyDE-Project/HyDE
- PrasanthRangan/hyprdots
- dim-ghub/Wallbash-UIs
- JaKooLit/Hyprland-Dotfiles
- end-4/dotfiles
- mylinuxforwork/dotfiles
- shub39/dotfiles
- Enerhim/CleanRice
- Hayyaoe/zenities
- SeraphimZelel/rio-ricing
- NischalDawadi/Hyprlust
and more that I couldn't name myself...
