#!/bin/bash

# List of files and directories to sync
files=(
    ".bashrc"
    ".gitconfig"
    ".config/btop"
    ".config/cava"
    ".config/dunst"
    ".config/fastfetch"
    ".config/fish"
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
    ".local/bin"
    ".config/alacritty"
    ".config/autostart"
    ".config/bat"
    ".config/boo"
    ".config/Kvantum"
    ".config/mpv"
    ".config/neofetch"
    ".config/normcap"
    ".config/pcmanfm"
    ".config/spicetify"
    ".config/swaylock"
    ".config/swaync"
    ".config/variety"
    ".config/waybar_1"
    ".config/waybar_3"
    ".config/libinput-gestures.conf"
    ".config/starship.toml"
    ".cache/wal"
    ".themes"
    ".mpd"

)

# Sync files
for file in "${files[@]}"; do
    cp -r "$HOME/$file" "$HOME/dotfiles/"
done

cd /home/jagan/dotfiles
git add .
git commit -m "Sync dotfiles"
git push

