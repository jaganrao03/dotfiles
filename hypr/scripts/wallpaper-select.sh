#!/bin/bash

# Configuration variables
WPATH="$HOME/.config/hypr/wallpaper"
CACHE_FILE="$HOME/.cache/current_wallpaper"
HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"
ROFI_THEME="$HOME/.config/rofi/wallpaper-select.rasi"
TRANSITION_FPS=60
TRANSITION_DURATION=2
TRANSITION_TYPE="grow"
TRANSITION_POS="0.925,0.977"
CONVERSION_LOG="$HOME/.cache/conversion_log.txt"
LOG_FILE="$HOME/.config/hypr/wallpaper.log"

# Ensure necessary files exist
touch "$CONVERSION_LOG"
touch "$LOG_FILE"

# Ensure necessary directories and files exist
mkdir -p "$WPATH"

# Logging function
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Function to set wallpaper for all connected outputs and display preview
set_wallpaper() {
    local file_path=$1
    swww query || swww init
    local outputs=$(swww query | grep -Po '^[A-Za-z0-9-]+(?=:)' | tr '\n' ',')
    outputs=${outputs%,} # Remove trailing comma
    log "Applying wallpaper to outputs: $outputs"
    swww img "$file_path" --outputs "$outputs" --transition-fps $TRANSITION_FPS --transition-type $TRANSITION_TYPE --transition-pos $TRANSITION_POS --transition-duration $TRANSITION_DURATION
    echo "$file_path" > "$CACHE_FILE"
    update_hyprlock_config "$file_path"
    update_colorscheme "$file_path"
}

# Function to update Hyprlock config
update_hyprlock_config() {
    local wallpaper_path=$1
    if [ -f "$HYPRLOCK_CONFIG" ]; then
        sed -i "/^background {/,/^}/ s|^\( *path = \).*|\1$wallpaper_path|" "$HYPRLOCK_CONFIG"
        local updated_path
        updated_path=$(grep "^path = " "$HYPRLOCK_CONFIG" | head -n 1 | cut -d ' ' -f 3)
        if [[ "$updated_path" == "$wallpaper_path" ]]; then
            log "Hyprlock config successfully updated with new wallpaper: $wallpaper_path"
            dunstify "Hyprlock Config Updated" "New lockscreen wallpaper set."
        else
            log "Failed to verify Hyprlock config update. Attempted path: $wallpaper_path, Found in config: $updated_path"
        fi
    else
        log "Hyprlock config file does not exist."
    fi
}

# Update the color scheme using Pywal
update_colorscheme() {
    local wallpaper_path=$1
    wal -i "$wallpaper_path" --saturate 0.8

    # Clear any existing content to prevent duplication
    > ~/.cache/wal/colors-hyprland.conf

    # Convert HEX to RGB and write to colors-hyprland.conf
    python3 ~/.config/hypr/scripts/convert_colors.py
    log "Colorscheme updated based on the wallpaper."
}

# Function to validate image
validate_image() {
    local file="$1"
    local errors
    errors=$(magick identify -format "%w %h %z %m" "$file")
    read -r width height depth format <<< "$errors"

    if [[ $width -lt 1920 || $height -lt 1080 ]]; then
        log "Image $file failed validation: must be at least 1920x1080. Current dimensions: ${width}x${height}, depth: ${depth}, format: ${format}"
        return 1
    fi
    return 0
}

# Function to convert image to PNG and validate
convert_and_validate_image() {
    local file_path=$1

    # Check if the file is already in the conversion log
    if grep -Fxq "$file_path" "$CONVERSION_LOG"; then
        log "$file_path is already converted and validated. Skipping conversion."
        echo "$file_path"
        return 0
    fi

    local new_name="$WPATH/wallpaper-$(date +%s).png"

    if [[ "$file_path" != *.png ]]; then
        if magick "$file_path" -resize 3840x2160! -depth 8 "$new_name"; then
            log "Converted $file_path to $new_name"
            if validate_image "$new_name"; then
                rm -f "$file_path"  # Delete the original file after successful conversion
                echo "$new_name" >> "$CONVERSION_LOG"  # Log the conversion
                echo "$new_name"
                return 0
            else
                rm -f "$new_name"
                return 1
            fi
        else
            log "Failed to convert $file_path to PNG format."
            return 1
        fi
    else
        if validate_image "$file_path"; then
            echo "$file_path" >> "$CONVERSION_LOG"  # Log the validation
            echo "$file_path"
            return 0
        else
            if magick "$file_path" -resize 3840x2160! -depth 8 "$new_name"; then
                log "Converted $file_path to $new_name"
                if validate_image "$new_name"; then
                    echo "$new_name" >> "$CONVERSION_LOG"  # Log the conversion
                    echo "$new_name"
                    return 0
                else
                    rm -f "$new_name"
                    return 1
                fi
            else
                log "Failed to convert $file_path to PNG format."
                return 1
            fi
        fi
    fi
}

# Function to select wallpaper with Rofi and display previews
select_wallpaper() {
    local files
    files=($(find "$WPATH" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \)))
    if [ ${#files[@]} -eq 0 ]; then
        log "No wallpapers found in $WPATH"
        exit 1
    fi

    local options=""
    for file in "${files[@]}"; do
        options="$options\n$file"
    done

    # Use rofi to select a wallpaper
    local selected_file
    selected_file=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -i -p "Select wallpaper:" -no-custom)
    if [ -z "$selected_file" ]; then
        log "No wallpaper selected"
        exit 1
    fi

    local converted_file
    converted_file=$(convert_and_validate_image "$selected_file")
    if [ $? -eq 0 ]; then
        set_wallpaper "$converted_file"
    else
        log "Selected file $selected_file could not be converted or validated."
        exit 1
    fi
}

# Main execution
select_wallpaper

