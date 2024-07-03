#!/bin/bash

# Configuration variables
WPATH="$HOME/.config/hypr/wallpaper"
UNSPLASH_API_URL="https://api.unsplash.com/photos/random"
UNSPLASH_ACCESS_KEY="9-Ozqk5O9YcAUD9f6m_cWDq09B5lwppBC5INvlDHPjg"
WALLHAVEN_API_URL="https://wallhaven.cc/api/v1/search"
WALLHAVEN_API_KEY="OVkf9N3gWpJWfCfhBVpCbdoQYw1Rd7Op"
cache_file="$HOME/.cache/current_wallpaper"
hyprlock_config="$HOME/.config/hypr/hyprlock.conf"
rofi_theme="$HOME/.config/rofi/wallpaper-select.rasi"
user_image="$HOME/.config/rofi/images/user.png"

# Ensure the wallpaper directory exists
mkdir -p "$WPATH"

# Function to manage wallpaper directory size
manage_directory() {
    local count=$(find "$WPATH" -type f -iname "*.png" | wc -l)
    if [ "$count" -gt 300 ]; then
        find "$WPATH" -type f -iname "*.png" | head -10 | xargs rm
        echo "Removed oldest 10 wallpapers to maintain directory limit."
    fi
}

# Function to set wallpaper and display preview
set_wallpaper() {
    local file_path=$1
    swaybg -i "$file_path" -m fill &
    echo "$file_path" > "$cache_file"
    dunstify "Wallpaper Changed" "Wallpaper successfully set: $file_path"
    update_hyprlock_config "$file_path"
    update_colorscheme "$file_path"
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

# Function to convert images to PNG and validate them
convert_and_validate_images() {
    echo "Converting and validating all images in $WPATH..."
    local counter=$(find "$WPATH" -type f -iname "wallpaper-*.png" | wc -l)
    
    for file in "$WPATH"/*; do
        if [[ "$file" != *.png ]]; then
            local new_name="$WPATH/wallpaper-$(printf "%04d" $((++counter))).png"
            # Convert to PNG, ensure compatibility with Hyprlock requirements
            if magick "$file" -resize 3840x2160! -depth 8 "$new_name"; then
                echo "Converted $file to $new_name"
                if validate_image "$new_name"; then
                    rm -f "$file"
                else
                    echo "Converted image $new_name does not meet Hyprlock requirements."
                    rm -f "$new_name"
                fi
            else
                echo "Failed to convert $file to PNG format."
            fi
        else
            local current_name="$file"
            local new_name="$WPATH/wallpaper-$(printf "%04d" $((++counter))).png"
            if [[ "$current_name" != "$new_name" ]]; then
                mv "$current_name" "$new_name"
                echo "Renamed $current_name to $new_name"
            fi
            if ! validate_image "$new_name"; then
                echo "Existing PNG image $new_name does not meet Hyprlock requirements."
                rm -f "$new_name"
            fi
        fi
    done
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

# Function to download wallpaper from Unsplash
download_from_unsplash() {
    local url="$UNSPLASH_API_URL?client_id=$UNSPLASH_ACCESS_KEY&query=nature"
    local response=$(curl -s "$url")
    local image_url=$(echo "$response" | jq -r '.urls.full')
    download_image "$image_url"
}

# Function to download wallpaper from Wallhaven
download_from_wallhaven() {
    local query="categories=111&purity=100&sorting=random&resolutions=3840x2160&seed=$(date +%s)"
    local response=$(curl -s -H "X-API-Key: $WALLHAVEN_API_KEY" "$WALLHAVEN_API_URL?$query")
    local wallpaper_url=$(echo "$response" | jq -r '.data[0].path')
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

# Process new downloads and existing files
process_new_downloads() {
    echo "Processing new downloads..."
    convert_and_validate_images
}

# Function to select wallpaper with Rofi and display previews
select_wallpaper() {
    local files
    files=$(find "$WPATH" -type f -iname "*.png")
    if [ -z "$files" ]; then
        echo "No wallpapers found"
        exit 1
    fi

    local options=""
    for file in $files; do
        options="$options\n$file"
    done

    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$rofi_theme" -i -p "Select wallpaper:" -no-custom -format d)
    if [ -z "$selected" ]; then
        echo "No wallpaper selected"
        exit 1
    fi

    local selected_file
    selected_file=$(echo "$files" | sed -n "${selected}p")
    set_wallpaper "$selected_file"
}

# Random wallpaper selection
random_wallpaper() {
    process_new_downloads
    local files=("$WPATH"/wallpaper-*.png)
    if (( ${#files[@]} > 0 )); then
        local random_idx=$(( RANDOM % ${#files[@]} ))
        local selected_wallpaper="${files[random_idx]}"
        echo "Selected wallpaper for random display: $selected_wallpaper"
        set_wallpaper "$selected_wallpaper"
    else
        echo "No valid wallpapers available to choose randomly."
    fi
}

# Initialize wallpaper from the cache
init_wallpaper() {
    if [ -f "$cache_file" ]; then
        local file_path
        file_path=$(cat "$cache_file")
        set_wallpaper "$file_path"
    else
        echo "No wallpaper cached to initialize."
    fi
}

# Update user image in power menu using Rofi
update_user_image() {
    echo "Select an image to update the user image..."
    local selected_img
    selected_img=$(find "$WPATH" -type f -iname "*.png" | rofi -dmenu -theme "$rofi_theme" -i -p "Select user image:")
    if [ -z "$selected_img" ]; then
        echo "No image selected."
    elif [ -f "$selected_img" ]; then
        cp "$selected_img" "$user_image"
        echo "User image updated to $selected_img"
    else
        echo "Selected file is not valid."
    fi
}

# Main execution logic
case $1 in
    download)
        download_wallpaper ;;
    select)
        select_wallpaper ;;
    random)
        random_wallpaper ;;
    init)
        init_wallpaper ;;
    update_user_image)
        update_user_image ;;
    *)
        echo "Usage: $0 {download|select|random|init|update_user_image}"
        exit 1 ;;
esac

