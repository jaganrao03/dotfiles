#!/bin/bash

# Configuration Variables
WPATH="$HOME/.config/hypr/wallpaper"
CACHE_FILE="$HOME/.cache/current_wallpaper"
HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"
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
        return 0
    fi

    local new_name="$WPATH/wallpaper-$(date +%s).png"

    if [[ "$file_path" != *.png ]]; then
        if magick "$file_path" -resize 3840x2160! -depth 8 "$new_name"; then
            log "Converted $file_path to $new_name"
            if validate_image "$new_name"; then
                rm -f "$file_path"  # Delete the original file after successful conversion
                echo "$new_name" >> "$CONVERSION_LOG"  # Log the conversion
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
            return 0
        else
            if magick "$file_path" -resize 3840x2160! -depth 8 "$new_name"; then
                log "Converted $file_path to $new_name"
                if validate_image "$new_name"; then
                    echo "$new_name" >> "$CONVERSION_LOG"  # Log the conversion
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

# Function to sanitize and rename wallpapers, convert to PNG if necessary
sanitize_filenames() {
    log "Sanitizing filenames..."
    local count=1
    local temp_ignore_pattern="8mtgo"  # Pattern to identify temporary files to ignore
    for file in "$WPATH"/*; do
        if [[ "$file" == *"$temp_ignore_pattern"* ]]; then
            log "Ignoring temporary or system file: $file"
            continue
        fi

        local new_name="$WPATH/wallpaper_${count}.png"
        if [[ "${file##*.}" != "png" ]]; then
            log "Converting $file to $new_name..."
            convert_and_validate_image "$file"
            mv -n "$file" "$new_name"
        elif [[ "$file" != "$new_name" ]]; then
            mv -n "$file" "$new_name"
        fi
        ((count++))
    done
    wait  # Wait for all background processes to complete
}

# Function to set wallpaper
set_wallpaper() {
    local file_path=$1
    if [[ -f "$file_path" ]]; then
        log "Setting wallpaper: $file_path"
        swww query || swww init
        swww img "$file_path" --transition-fps $TRANSITION_FPS --transition-type $TRANSITION_TYPE --transition-pos $TRANSITION_POS --transition-duration $TRANSITION_DURATION
        echo "$file_path" > "$CACHE_FILE"
        update_hyprlock_config "$file_path"
        update_colorscheme "$file_path"
        notify_user "Wallpaper changed" "New wallpaper set from $file_path"
    else
        log "Error: Wallpaper file not found: $file_path"
        exit 1
    fi
}

# Function to update Hyprlock config
update_hyprlock_config() {
    local wallpaper_path=$1
    if [ -f "$HYPRLOCK_CONFIG" ]; then
        sed -i "/^background {/,/^}/ s|^\( *path = \).*|\1$wallpaper_path|" "$HYPRLOCK_CONFIG"
        log "Hyprlock config updated with new wallpaper: $wallpaper_path"
    else
        log "Hyprlock config file does not exist."
    fi
}

# Function to update the color scheme using Pywal and convert colors for Hyprland
update_colorscheme() {
    local wallpaper_path=$1
    log "Updating color scheme for wallpaper: $wallpaper_path"

    # Clear any existing Pywal cache to ensure fresh color generation
    wal -c

    # Generate new colors using Pywal without using the cache
    wal -i "$wallpaper_path" --saturate 0.8 -n

    # Check if Pywal generated the colors successfully
    if [ -s ~/.cache/wal/colors.sh ]; then
        # Convert HEX to RGB and write to colors-hyprland.conf
        python3 ~/.config/hypr/scripts/convert_colors.py
        log "Colorscheme successfully updated based on the wallpaper."
    else
        log "Failed to generate colors. Please check the wallpaper quality or Pywal installation."
    fi
}

# Function to ensure swww-daemon is running
ensure_swww_daemon_running() {
    if ! pgrep -x "swww-daemon" > /dev/null; then
        log "Starting swww-daemon..."
        swww-daemon &
        sleep 1  # Give swww-daemon a moment to start
    fi
}

# Function to notify user
notify_user() {
    local title=$1
    local message=$2
    dunstify "$title" "$message"
}

# Select and set random wallpaper
random_select_wallpaper() {
    sanitize_filenames
    ensure_swww_daemon_running
    local files=("$WPATH"/wallpaper_*.png)
    local num_files=${#files[@]}
    if (( num_files == 0 )); then
        log "No valid wallpapers found in $WPATH"
        exit 1
    fi
    local random_index=$((RANDOM % num_files))
    local selected_file="${files[$random_index]}"

    log "Selected file: $selected_file"
    set_wallpaper "$selected_file"
}

# Function to change wallpaper at intervals
change_wallpaper_periodically() {
    local interval=$1
    while true; do
        random_select_wallpaper
        log "Wallpaper will change again in $interval seconds."
        sleep "$interval"
    done
}

# Main execution block
if [[ $1 == "--interval" && -n $2 ]]; then
    change_wallpaper_periodically $2
else
    random_select_wallpaper
fi

