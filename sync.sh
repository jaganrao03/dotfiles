#!/bin/bash

# List of files and directories to sync
files=(
    ".bashrc"
    ".gitconfig"
    ".scripts"
    ".config/btop"
    ".config/cava"
    ".config/dunst"
    ".config/fastfetch"
    ".config/fish"
    ".config/hyde"
    ".config/hypr"
    ".config/kitty"
    ".config/nvim"
    ".config/nwg-look"
    ".config/qt5ct"
    ".config/qt6ct"
    ".config/ranger"
    ".config/rofi"
    ".config/tofi"
    ".config/touchegg"
    ".config/waybar"
    ".config/wlogout"
    ".config/wofi"
    ".config/xsettingsd"
)

# Sync files
for file in "${files[@]}"; do
    cp -r "$HOME/$file" "$HOME/dotfiles/"
done

#cd /home/jagan/dotfiles
#git add .
#git commit -m "Sync dotfiles"
#git push

