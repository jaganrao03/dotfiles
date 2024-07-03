#!/bin/bash

# Configuration variables
WPATH="$HOME/.config/hypr/wallpaper"
cache_file="$HOME/.cache/current_wallpaper"
hyprlock_config="$HOME/.config/hypr/hyprlock.conf"
used_wallpapers_file="$HOME/.cache/used_wallpapers"
rofi_theme="$HOME/.config/rofi/wallpaper-select.rasi"

# Function to set wallpaper and display preview
set_wallpaper() {
    local file_path=$1
    swaybg -i "$file_path" -m fill &
    echo "$file_path" > "$cache_file"
    #dunstify "Wallpaper Changed" "Wallpaper successfully set: $file_path"
    update_hyprlock_config "$file_path"
    update_colorscheme "$file_path"
}

# Function to update Hyprlock config
update_hyprlock_config() {
    local wallpaper_path=$1
    if [ -f "$hyprlock_config" ]; then
        sed -i "/^background {/,/^}/ s|^\( *path = \).*|\1$wallpaper_path|" "$hyprlock_config"
        local updated_path
        updated_path=$(grep "^path = " "$hyprlock_config" | head -n 1 | cut -d ' ' -f 3)
        if [[ "$updated_path" == "$wallpaper_path" ]]; then
            echo "Hyprlock config successfully updated with new wallpaper: $wallpaper_path"
            dunstify "Hyprlock Config Updated" "New lockscreen wallpaper set."
        else
            echo "Failed to verify Hyprlock config update. Attempted path: $wallpaper_path, Found in config: $updated_path"
        fi
    else
        echo "Hyprlock config file does not exist."
    fi
}

# Update the color scheme using Pywal
update_colorscheme() {
    local wallpaper_path=$1
    wal -i "$wallpaper_path" --saturate 0.8
    kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf || true  # Ignore errors
    echo "Colorscheme updated based on the wallpaper."
}

# Function to validate image
validate_image() {
    local file="$1"
    local errors
    errors=$(magick identify -format "%w %h %z %m" "$file")
    read -r width height depth format <<< "$errors"

    if [[ $width -lt 1920 || $height -lt 1080 ]]; then
        echo "Image $file failed validation: must be at least 1920x1080."
        echo "Current dimensions: ${width}x${height}, depth: ${depth}, format: ${format}"
        return 1
    fi
    return 0
}

# Function to convert image to PNG and validate
convert_and_validate_image() {
    local file_path=$1
    local new_name="$WPATH/wallpaper-$(date +%s).png"

    if [[ "$file_path" != *.png ]]; then
        if magick "$file_path" -resize 3840x2160! -depth 8 "$new_name"; then
            echo "Converted $file_path to $new_name"
            if validate_image "$new_name"; then
                rm -f "$file_path"  # Delete the original file after successful conversion
                echo "$new_name"
                return 0
            else
                rm -f "$new_name"
                return 1
            fi
        else
            echo "Failed to convert $file_path to PNG format."
            return 1
        fi
    else
        if validate_image "$file_path"; then
            echo "$file_path"
            return 0
        else
            if magick "$file_path" -resize 3840x2160! -depth 8 "$new_name"; then
                echo "Converted $file_path to $new_name"
                if validate_image "$new_name"; then
                    echo "$new_name"
                    return 0
                else
                    rm -f "$new_name"
                    return 1
                fi
            else
                echo "Failed to convert $file_path to PNG format."
                return 1
            fi
        fi
    fi
}

# Function to randomly select a wallpaper and ensure it's not a repeat
random_select_wallpaper() {
    local files
    files=($(find "$WPATH" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \)))
    if [ ${#files[@]} -eq 0 ]; then
        echo "No wallpapers found in $WPATH"
        exit 1
    fi

    # Read used wallpapers
    touch "$used_wallpapers_file"
    readarray -t used_wallpapers < "$used_wallpapers_file"

    # Filter out used wallpapers
    local new_files=()
    for file in "${files[@]}"; do
        if ! printf '%s\n' "${used_wallpapers[@]}" | grep -qx "$file"; then
            new_files+=("$file")
        fi
    done

    # If all wallpapers have been used, clear the used list
    if [ ${#new_files[@]} -eq 0 ]; then
        echo "All wallpapers have been used, starting over."
        > "$used_wallpapers_file"
        new_files=("${files[@]}")
    fi

    # Select a random wallpaper from the new list
    local selected_file
    selected_file=${new_files[RANDOM % ${#new_files[@]}]}

    # Add the selected wallpaper to the used list
    echo "$selected_file" >> "$used_wallpapers_file"

    # Validate and convert if necessary
    local converted_file
    converted_file=$(convert_and_validate_image "$selected_file")
    if [ $? -eq 0 ]; then
        set_wallpaper "$converted_file"
    else
        echo "Selected file $selected_file could not be converted or validated."
        exit 1
    fi
}

# Main execution
random_select_wallpaper

