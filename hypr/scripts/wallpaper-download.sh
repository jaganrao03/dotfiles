#!/bin/bash

# Configuration variables
WPATH="$HOME/.config/hypr/wallpaper"
UNSPLASH_API_URL="https://api.unsplash.com/photos/random"
UNSPLASH_ACCESS_KEY="9-Ozqk5O9YcAUD9f6m_cWDq09B5lwppBC5INvlDHPjg"
WALLHAVEN_API_URL="https://wallhaven.cc/api/v1/search"
WALLHAVEN_API_KEY="OVkf9N3gWpJWfCfhBVpCbdoQYw1Rd7Op"
REDDIT_USER_AGENT="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:88.0) Gecko/20100101 Firefox/88.0"
CACHE_FILE="$HOME/.cache/current_wallpaper"
HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"
TRACKED_URLS_FILE="$HOME/.cache/tracked_wallpapers.log"
TRANSITION_FPS=60
TRANSITION_DURATION=2
TRANSITION_TYPE="grow"
TRANSITION_POS="0.925,0.977"
LOG_FILE="$HOME/.config/hypr/wallpaper.log"

# Ensure the wallpaper directory exists
mkdir -p "$WPATH"
# Ensure the tracked URLs file exists
touch "$TRACKED_URLS_FILE"
# Ensure the log file exists
touch "$LOG_FILE"

# Logging function
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
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
            magick "$file" "$new_name" &
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

# Function to retry download
retry() {
    local n=1
    local max=3
    local delay=5
    while true; do
        "$@" && break || {
            if [[ $n -lt $max ]]; then
                ((n++))
                log "Command failed. Attempt $n/$max:"
                sleep $delay;
            else
                log "The command has failed after $n attempts."
                return 1
            fi
        }
    done
}

# Function to download from Unsplash
download_from_unsplash() {
    log "Attempting to download from Unsplash..."
    local url="$UNSPLASH_API_URL?client_id=$UNSPLASH_ACCESS_KEY&orientation=landscape&w=3840&h=2160"
    local response=$(curl -s "$url")
    local image_url=$(echo "$response" | jq -r '.urls.full')
    if [[ -z "$image_url" || "$image_url" == "null" ]]; then
        log "Failed to retrieve image URL from Unsplash."
        return 1
    fi
    if grep -Fxq "$image_url" "$TRACKED_URLS_FILE"; then
        log "Image URL already downloaded: $image_url"
        return 1
    fi
    log "Downloading from Unsplash: $image_url"
    download_image "$image_url" && echo "$image_url" >> "$TRACKED_URLS_FILE"
}

# Function to download from Wallhaven
download_from_wallhaven() {
    log "Attempting to download from Wallhaven..."
    local tags="anime,cars,nature,landscape"
    local query="categories=111&purity=100&sorting=random&resolutions=3840x2160&seed=$(date +%s)&q=$tags"
    local response=$(curl -s -H "X-API-Key: $WALLHAVEN_API_KEY" "$WALLHAVEN_API_URL?$query")
    local wallpaper_url=$(echo "$response" | jq -r '.data[0].path')
    if [[ -z "$wallpaper_url" || "$wallpaper_url" == "null" ]]; then
        log "Failed to retrieve image URL from Wallhaven."
        return 1
    fi
    if grep -Fxq "$wallpaper_url" "$TRACKED_URLS_FILE"; then
        log "Image URL already downloaded: $wallpaper_url"
        return 1
    fi
    log "Downloading from Wallhaven: $wallpaper_url"
    download_image "$wallpaper_url" && echo "$wallpaper_url" >> "$TRACKED_URLS_FILE"
}

# Function to download from Reddit
download_from_reddit() {
    log "Attempting to download from Reddit..."
    local subreddit="wallpaper"
    local url="https://www.reddit.com/r/${subreddit}/hot/.json?limit=25"
    local headers="User-Agent: $REDDIT_USER_AGENT"

    local response=$(curl -s -H "${headers}" "$url")
    local image_urls=($(echo "$response" | jq -r '.data.children[] | select(.data.post_hint == "image") | .data.url_overridden_by_dest'))

    # Filter out common low-resolution formats like thumbnails or previews
    image_urls=($(printf "%s\n" "${image_urls[@]}" | grep -E '\.(jpg|jpeg|png)$'))

    # Shuffle array to randomize which wallpaper gets picked
    image_urls=($(shuf -e "${image_urls[@]}"))

    for image_url in "${image_urls[@]}"; do
        if grep -Fxq "$image_url" "$TRACKED_URLS_FILE"; then
            log "Image URL already downloaded: $image_url"
            continue
        fi

        log "Downloading from Reddit: $image_url"
        if download_image "$image_url"; then
            echo "$image_url" >> "$TRACKED_URLS_FILE"
            return 0  # Successful download
        fi
    done

    return 1  # Failed to download any new image
}

# Function to download image
download_image() {
    local image_url=$1
    # Properly handle filename extraction and conversion
    local filename=$(basename "${image_url%%\?*}")  # Remove URL parameters
    local count=$(ls "$WPATH" | grep -Eo 'wallpaper_[0-9]+' | sort -n | tail -1 | grep -Eo '[0-9]+')
    count=$((count+1))
    local new_name="$WPATH/wallpaper_${count}.png"

    # Ensure the filename is unique and does not overwrite existing files
    while [[ -f "$new_name" ]]; do
        count=$((count+1))
        new_name="$WPATH/wallpaper_${count}.png"
    done

    # Download the image and directly convert it to PNG
    if retry curl -s "$image_url" | magick convert - -resize 3840x2160\! -quality 100 "$new_name"; then
        log "Downloaded and converted to high-quality PNG: $new_name"

        local width=$(magick identify -format "%w" "$new_name")
        local height=$(magick identify -format "%h" "$new_name")

        # Check resolution requirements
        if [[ $width -lt 3840 || $height -lt 2160 ]]; then
            log "Image does not meet resolution requirements: ${width}x${height}"
            rm -f "$new_name"
            return 1
        fi

        if validate_image "$new_name"; then
            set_wallpaper "$new_name"
        else
            log "Downloaded image $new_name does not meet Hyprlock requirements."
            rm -f "$new_name"
            return 1
        fi
    else
        log "Failed to download or convert wallpaper from: $image_url"
        return 1
    fi
}

# Function to validate image
validate_image() {
    local file="$1"
    local errors
    errors=$(magick identify -format "%w %h %z %m" "$file")
    read -r width height depth format <<< "$errors"

    if [[ $width -ne 3840 || $height -ne 2160 || $depth -ne 8 ]]; then
        log "Image $file failed validation: must be 3840x2160, 8-bit depth."
        return 1
    fi
    return 0
}

# Function to download and set a new wallpaper
download_and_set_wallpaper() {
    local success=0
    local retry_count=3

    for ((i=0; i<$retry_count; i++)); do
        log "Attempting to download from Reddit (Attempt $((i+1))/$retry_count)..."
        if download_from_reddit; then
            success=1
            break
        fi

        log "Attempting to download from Unsplash (Attempt $((i+1))/$retry_count)..."
        if download_from_unsplash; then
            success=1
            break
        fi

        log "Attempting to download from Wallhaven (Attempt $((i+1))/$retry_count)..."
        if download_from_wallhaven; then
            success=1
            break
        fi
    done

    if [[ $success -eq 0 ]]; then
        log "All download attempts from all sources failed."
        exit 1
    fi

    sanitize_filenames
}

# Main execution
ensure_swww_daemon_running
download_and_set_wallpaper
sanitize_filenames

