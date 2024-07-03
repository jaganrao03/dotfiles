#!/bin/bash

# Configuration variables
WPATH="$HOME/.config/hypr/wallpaper"
UNSPLASH_API_URL="https://api.unsplash.com/photos/random"
UNSPLASH_ACCESS_KEY="9-Ozqk5O9YcAUD9f6m_cWDq09B5lwppBC5INvlDHPjg"
WALLHAVEN_API_URL="https://wallhaven.cc/api/v1/search"
WALLHAVEN_API_KEY="OVkf9N3gWpJWfCfhBVpCbdoQYw1Rd7Op"
cache_file="$HOME/.cache/current_wallpaper"
hyprlock_config="$HOME/.config/hypr/hyprlock.conf"

# Ensure the wallpaper directory exists
mkdir -p "$WPATH"

# Function to download wallpaper from Unsplash
download_from_unsplash() {
    local url="$UNSPLASH_API_URL?client_id=$UNSPLASH_ACCESS_KEY&query=nature&orientation=landscape"
    local response=$(curl -s "$url")
    local image_url=$(echo "$response" | jq -r '.urls.full')
    if [[ -z "$image_url" || "$image_url" == "null" ]]; then
        echo "Failed to retrieve image URL from Unsplash."
        return 1
    fi
    download_image "$image_url"
}

# Function to download wallpaper from Wallhaven
download_from_wallhaven() {
    local query="categories=111&purity=100&sorting=random&resolutions=3840x2160&seed=$(date +%s)"
    local response=$(curl -s -H "X-API-Key: $WALLHAVEN_API_KEY" "$WALLHAVEN_API_URL?$query")
    local wallpaper_url=$(echo "$response" | jq -r '.data[0].path')
    if [[ -z "$wallpaper_url" || "$wallpaper_url" == "null" ]]; then
        echo "Failed to retrieve image URL from Wallhaven."
        return 1
    fi
    download_image "$wallpaper_url"
}

# Function to download image
download_image() {
    local image_url=$1
    local counter=$(find "$WPATH" -type f -iname "wallpaper-*.png" | wc -l)
    local file_path="$WPATH/wallpaper-$(printf "%04d" $((counter + 1))).png"
    
    if curl -s "$image_url" | magick - -resize 3840x2160! -depth 8 "$file_path"; then
        echo "Downloaded and converted new wallpaper: $file_path"
        if validate_image "$file_path"; then
            set_wallpaper "$file_path"
        else
            echo "Downloaded image $file_path does not meet Hyprlock requirements."
            rm -f "$file_path"
        fi
    else
        echo "Failed to download or convert wallpaper."
    fi
}

# Function to validate image
validate_image() {
    local file="$1"
    local errors
    errors=$(magick identify -format "%w %h %z %m" "$file")
    read -r width height depth format <<< "$errors"

    if [[ $width -ne 3840 || $height -ne 2160 || $depth -ne 8 ]]; then
        echo "Image $file failed validation: must be 3840x2160, 8-bit depth."
        return 1
    fi
    return 0
}

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
        sed -i '/^background {/,/^}/ s|^\( *path = \).*|\1'"$wallpaper_path"'|' "$hyprlock_config"
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
    kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf
    echo "Colorscheme updated based on the wallpaper."
}

# Function to download and set a new wallpaper
download_and_set_wallpaper() {
    # Randomly select an API to download wallpaper from
    if (( RANDOM % 2 )); then
        download_from_unsplash || download_from_wallhaven
    else
        download_from_wallhaven || download_from_unsplash
    fi
}

# Main execution
download_and_set_wallpaper

