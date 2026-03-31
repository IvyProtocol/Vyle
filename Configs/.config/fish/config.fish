if status is-interactive
	#set -U fish_greeting ""
	starship init fish | source

	alias pamcan pacman
	alias env_pkg="$HOME/.config/fish/fish_scripts/env_pkg.sh"
	alias zimg="kitty +kitten icat"
	set EDITOR nvim
end
set fish_user_paths ~/.local/bin
