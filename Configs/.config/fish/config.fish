if status is-interactive
    #set -U fish_greeting ""
    starship init fish | source

    alias zimg="kitty +kitten icat"
    set EDITOR nvim
end

fish_add_path /home/iris/.spicetify
set fish_user_paths ~/.local/lib/vyleu
