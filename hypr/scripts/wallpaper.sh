#!/bin/bash
#                _ _
# __      ____ _| | |_ __   __ _ _ __   ___ _ __
# \ \ /\ / / _` | | | '_ \ / _` | '_ \ / _ \ '__|
#  \ V  V / (_| | | | |_) | (_| | |_) |  __/ |
#   \_/\_/ \__,_|_|_| .__/ \__,_| .__/ \___|_|
#                   |_|         |_|

# -----------------------------------------------------
# Wallpaper Management Script
# -----------------------------------------------------

# Define configuration variables
wallpaper_folder="$HOME/.config/hypr/wallpaper" # Directory with wallpaper images
used_wallpaper="$HOME/.cache/used_wallpaper"
cache_file="$HOME/.cache/current_wallpaper"
blurred="$HOME/.cache/blurred_wallpaper.png"
square="$HOME/.cache/square_wallpaper.png"
rasi_file="$HOME/.cache/current_wallpaper.rasi"
blur_strength="50x30"
wallpaper_engine="hyprpaper"
#wallpaper_engine="swww"
wallpaper_effect="off" # or "on"

# Ensure blur file exists
if [ -f "$blur_file" ]; then
    blur=$(cat $blur_file)
else
    blur="50x30"
fi

# Create cache file if it doesn't exist
if [ ! -f $cache_file ] ;then
    touch $cache_file
    echo "$wallpaper_folder/default.jpg" > "$cache_file"
fi

# Create rasi file if it doesn't exist
if [ ! -f $rasi_file ] ;then
    touch $rasi_file
    echo "* { current-image: url(\"$wallpaper_folder/default.jpg\", height); }" > "$rasi_file"
fi

current_wallpaper=$(cat "$cache_file")

case $1 in

    # Load wallpaper from .cache of last session
    "init")
        sleep 1
        if [ -f $cache_file ]; then
            wal -q -i $current_wallpaper
        else
            wal -q -i $wallpaper_folder/
        fi
    ;;

    # Select wallpaper with rofi
    "select")
        sleep 0.2
        selected=$( find "$wallpaper_folder" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -exec basename {} \; | sort -R | while read rfile
        do
            echo -en "$rfile\x00icon\x1f$wallaper_folder/${rfile}\n"
        done | rofi -dmenu -i -replace -config ~/.cache/config-wallpaper.rasi)
        if [ ! "$selected" ]; then
            echo "No wallpaper selected"
            exit
        fi
        current_wallpaper="$wallpaper_folder/$selected"
        wal -q -i $current_wallpaper
        echo "$current_wallpaper" > "$cache_file"
        echo "Selected wallpaper: $current_wallpaper"
    ;;

    # Randomly select wallpaper
    *)
        wal -q -i $wallpaper_folder/
        current_wallpaper=$(find "$wallpaper_folder" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort -R | head -n 1)
        echo "$current_wallpaper" > "$cache_file"
        echo "Random wallpaper: $current_wallpaper"
    ;;

esac

# -----------------------------------------------------
# Load current pywal color scheme
# -----------------------------------------------------
source "$HOME/.cache/wal/colors.sh"

# -----------------------------------------------------
# get wallpaper image name
# -----------------------------------------------------
newwall=$(echo $current_wallpaper | sed "s|$wallpaper_folder/||g")

# -----------------------------------------------------
# Reload waybar with new colors
# -----------------------------------------------------
~/.config/hypr/scripts/launch_waybar

# -----------------------------------------------------
# Set the new wallpaper
# -----------------------------------------------------
transition_type="wipe"
# transition_type="outer"
# transition_type="random"

cp $current_wallpaper $HOME/.cache/
mv $HOME/.cache/$newwall $used_wallpaper

# Load Wallpaper Effect
if [ -f $wallpaper_effect ] ;then
    effect=$(cat $wallpaper_effect)
    if [ ! "$effect" == "off" ] ;then
        if [ "$1" == "init" ] ;then
            echo ":: Init"
        else
            dunstify "Using wallpaper effect $effect..." "with image $newwall" -h int:value:10 -h string:x-dunst-stack-tag:wallpaper
        fi
        source $HOME/.config/hypr/scripts/hypr/effects/wallpaper/$effect
    fi
fi

if [ "$1" == "init" ] ;then
    echo ":: Init"
else
    sleep 1
    dunstify "Changing wallpaper ..." "with image $newwall" -h int:value:25 -h string:x-dunst-stack-tag:wallpaper

    # -----------------------------------------------------
    # Reload Hyprland configurations
    # -----------------------------------------------------
    killall swww-daemon &
fi

# Check if swww-daemon is running and start if not
if ! pgrep -x "swww-daemon" > /dev/null
then
    echo "Starting swww-daemon..."
    swww-daemon &
fi

if [ "$wallpaper_engine" == "swww" ] ;then
    echo ":: Using swww"
    swww img $used_wallpaper \
        --transition-bezier .43,1.19,1,.4 \
        --transition-fps=60 \
        --transition-type=$transition_type \
        --transition-duration=0.7 \
        --transition-pos "$( hyprctl cursorpos )"
elif [ "$wallpaper_engine" == "hyprpaper" ] ;then
    echo ":: Using hyprpaper"
    killall hyprpaper
    wal_tpl=$(cat $HOME/.config/hypr/hyprpaper/hyprpaper.tpl)
    output=${wal_tpl//WALLPAPER/$used_wallpaper}
    mkdir -p $HOME/.config/hypr/scripts/hypr
    echo "$output" > $HOME/.config/hypr/hyprpaper/hyprpaper.conf
    hyprpaper &
else
    echo ":: Wallpaper Engine disabled"
fi
