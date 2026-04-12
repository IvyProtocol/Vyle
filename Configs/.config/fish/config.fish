if status is-interactive
    #set -U fish_greeting ""
    starship init fish | source
    alias pamcan pacman
    alias zimg="kitty +kitten icat"
    set EDITOR nvim
end

set fish_user_paths ~/.local/lib/vyle/
