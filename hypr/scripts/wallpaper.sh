#!/bin/bash

# Configuration variables
WPATH="$HOME/.config/hypr/wallpaper"
UNSPLASH_API_URL="https://api.unsplash.com/photos/random"
UNSPLASH_ACCESS_KEY="9-Ozqk5O9YcAUD9f6m_cWDq09B5lwppBC5INvlDHPjg"
UNSPLASH_SEARCH_URL="https://api.unsplash.com/search/photos"
WALLHAVEN_API_URL="https://wallhaven.cc/api/v1/search"
WALLHAVEN_API_KEY="OVkf9N3gWpJWfCfhBVpCbdoQYw1Rd7Op"
REDDIT_USER_AGENT="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:88.0) Gecko/20100101 Firefox/88.0"
CACHE_FILE="$HOME/.cache/current_wallpaper"
HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"
ROFI_THEME="$HOME/.config/rofi/wallpaper-select.rasi"
#ROFI_THEME="$HOME/test.rasi"
USER_IMAGE="$HOME/.config/rofi/images/user.png"
TRANSITION_FPS=165
TRANSITION_DURATION=2
TRANSITION_TYPE="random"
TRANSITION_POS="0.925,0.977"
CONVERSION_LOG="$HOME/.cache/conversion_log.txt"
LOG_FILE="$HOME/.config/hypr/wallpaper.log"
TRACKED_URLS_FILE="$HOME/.cache/tracked_wallpapers.log"
INTERVAL=300 # Default interval for slideshow in seconds

# Ensure necessary files and directories exist
mkdir -p "$WPATH"
touch "$CONVERSION_LOG"
touch "$LOG_FILE"
touch "$TRACKED_URLS_FILE"

# Logging function
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Function to sanitize and rename wallpapers, convert to PNG if necessary
sanitize_filenames() {
    log "Sanitizing filenames..."
    local count=1
    local temp_ignore_pattern="8mtgo"
    for file in "$WPATH"/*; do
        if [[ "$file" == *"$temp_ignore_pattern"* ]]; then
            log "Ignoring temporary or system file: $file"
            continue
        fi

        local new_name="$WPATH/wallpaper_${count}.png"
        if [[ "${file##*.}" != "png" ]]; then
            log "Converting $file to $new_name..."
            magick "$file" "$new_name" && rm "$file"
        elif [[ "$file" != "$new_name" ]]; then
            mv -n "$file" "$new_name"
        fi
        ((count++))
    done
}

# Update the set_wallpaper function to call update_sddm_wallpaper
set_wallpaper() {
    local file_path=$1
    if [[ -f "$file_path" ]]; then
        log "Setting wallpaper: $file_path"
        ensure_swww_daemon_running
        if ! swww query; then
            log "swww-daemon is not running"
            exit 1
        fi
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

# Function to update the color scheme using Pywal
update_colorscheme() {
    local wallpaper_path=$1
    log "Updating color scheme for wallpaper: $wallpaper_path"

    wal -c
    wal -i "$wallpaper_path" --saturate 0.8 -n

    if [ -s ~/.cache/wal/colors.sh ]; then
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
        swww-daemon --format xrgb &
        sleep 1
    fi
}

# Function to notify user
notify_user() {
    local title=$1
    local message=$2
    dunstify "$title" "$message"
}

# Function to retry a command with exponential backoff
retry_command() {
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

# Function to download image
download_image() {
    local image_url=$1
    local count=$(ls "$WPATH" | grep -Eo 'wallpaper_[0-9]+' | sort -n | tail -1 | grep -Eo '[0-9]+')
    count=$((count+1))
    local new_name="$WPATH/wallpaper_${count}.png"

    while [[ -f "$new_name" ]]; do
        count=$((count+1))
        new_name="$WPATH/wallpaper_${count}.png"
    done

    if retry_command curl -s "$image_url" | magick convert - -resize 3840x2160^ -gravity center -extent 3840x2160 -depth 8 "$new_name"; then
        log "Downloaded and converted new wallpaper: $new_name"
        if validate_image "$new_name"; then
            set_wallpaper "$new_name"
        else
            log "Downloaded image does not meet requirements: $new_name"
            rm -f "$new_name"
        fi
    else
        log "Failed to download or convert wallpaper from URL: $image_url"
    fi
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
    local query="categories=111&purity=100&sorting=random&resolutions=3840x2160&seed=$(date +%s)"
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

    image_urls=($(printf "%s\n" "${image_urls[@]}" | grep -E '\.(jpg|jpeg|png)$'))

    image_urls=($(shuf -e "${image_urls[@]}"))

    for image_url in "${image_urls[@]}"; do
        if grep -Fxq "$image_url" "$TRACKED_URLS_FILE"; then
            log "Image URL already downloaded: $image_url"
            continue
        fi

        log "Downloading from Reddit: $image_url"
        if download_image "$image_url"; then
            echo "$image_url" >> "$TRACKED_URLS_FILE"
            return 0
        fi
    done

    return 1
}

# Function to download and set a new wallpaper
download_and_set_wallpaper() {
    local success=0
    local retry_count=3
    local download_sources=("download_from_reddit" "download_from_unsplash" "download_from_wallhaven")

    for ((i=0; i<$retry_count; i++)); do
        download_sources=($(shuf -e "${download_sources[@]}"))  # Shuffle the sources array

        for source in "${download_sources[@]}"; do
            log "Attempting to download from ${source##*_} (Attempt $((i+1))/$retry_count)..."
            if $source; then
                success=1
                break
            fi
        done

        if [[ $success -eq 1 ]]; then
            break
        fi
    done

    if [[ $success -eq 0 ]]; then
        log "All download attempts from all sources failed."
        exit 1
    fi

    sanitize_filenames
}

# Function to download and format image
download_and_format_image() {
    local image_url=$1
    local count=$(ls "$WPATH" | grep -Eo 'wallpaper_[0-9]+' | sort -n | tail -1 | grep -Eo '[0-9]+')
    count=$((count+1))
    local new_name="$WPATH/wallpaper_${count}.png"

    while [[ -f "$new_name" ]]; do
        count=$((count+1))
        new_name="$WPATH/wallpaper_${count}.png"
    done

    if retry_command curl -s "$image_url" | magick convert - -resize 3840x2160^ -gravity center -extent 3840x2160 -depth 8 "$new_name"; then
        log "Downloaded and converted new wallpaper: $new_name"
        if validate_image "$new_name"; then
            set_wallpaper "$new_name"
        else
            log "Downloaded image does not meet requirements: $new_name"
            rm -f "$new_name"
        fi
    else
        log "Failed to download or convert wallpaper from URL: $image_url"
    fi
}

# Function to search for an image based on a search phrase
search_and_download_image() {
    log "Searching for image..."
    local search_phrase=$(rofi -dmenu -theme "$ROFI_THEME" -i -p "Enter search phrase:")
    if [ -z "$search_phrase" ]; then
        log "No search phrase entered."
        exit 1
    fi
    local source=$(echo -e "Unsplash\nWallhaven\nReddit" | rofi -dmenu -theme "$ROFI_THEME" -i -p "Select source:")
    if [ -z "$source" ]; then
        log "No source selected."
        exit 1
    fi
    case $source in
        "Unsplash")
            search_from_unsplash "$search_phrase"
            ;;
        "Wallhaven")
            search_from_wallhaven "$search_phrase"
            ;;
        "Reddit")
            search_from_reddit "$search_phrase"
            ;;
        *)
            log "Invalid source selected."
            exit 1
            ;;
    esac
    sanitize_filenames
}

# Function to search from Unsplash
search_from_unsplash() {
    local search_phrase="$1"
    log "Searching Unsplash for: $search_phrase"
    local url="$UNSPLASH_SEARCH_URL?client_id=$UNSPLASH_ACCESS_KEY&query=$(echo $search_phrase | sed 's/ /%20/g')&orientation=landscape&w=3840&h=2160"
    local response=$(curl -s "$url")
    local image_urls=($(echo "$response" | jq -r '.results[].urls.full'))

    image_urls=($(shuf -e "${image_urls[@]}"))

    for image_url in "${image_urls[@]}"; do
        if grep -Fxq "$image_url" "$TRACKED_URLS_FILE"; then
            log "Image URL already downloaded: $image_url"
            continue
        fi

        log "Downloading from Unsplash: $image_url"
        if download_image "$image_url"; then
            echo "$image_url" >> "$TRACKED_URLS_FILE"
            return 0
        fi
    done

    return 1
}

# Function to search from Wallhaven
search_from_wallhaven() {
    local search_phrase="$1"
    log "Searching Wallhaven for: $search_phrase"
    local query="q=$(echo $search_phrase | sed 's/ /%20/g')&categories=111&purity=100&sorting=random&resolutions=3840x2160&seed=$(date +%s)"
    local response=$(curl -s -H "X-API-Key: $WALLHAVEN_API_KEY" "$WALLHAVEN_API_URL?$query")
    local image_urls=($(echo "$response" | jq -r '.data[].path'))

    image_urls=($(shuf -e "${image_urls[@]}"))

    for image_url in "${image_urls[@]}"; do
        if grep -Fxq "$image_url" "$TRACKED_URLS_FILE"; then
            log "Image URL already downloaded: $image_url"
            continue
        fi

        log "Downloading from Wallhaven: $image_url"
        if download_image "$image_url"; then
            echo "$image_url" >> "$TRACKED_URLS_FILE"
            return 0
        fi
    done

    return 1
}

# Function to search from Reddit
search_from_reddit() {
    local search_phrase="$1"
    log "Searching Reddit for: $search_phrase"
    local url="https://www.reddit.com/search.json?q=$(echo $search_phrase | sed 's/ /%20/g')&limit=25&sort=hot"
    local headers="User-Agent: $REDDIT_USER_AGENT"

    local response=$(curl -s -H "${headers}" "$url")
    local image_urls=($(echo "$response" | jq -r '.data.children[] | select(.data.post_hint == "image") | .data.url_overridden_by_dest'))

    image_urls=($(printf "%s\n" "${image_urls[@]}" | grep -E '\.(jpg|jpeg|png)$'))

    image_urls=($(shuf -e "${image_urls[@]}"))

    for image_url in "${image_urls[@]}"; do
        if grep -Fxq "$image_url" "$TRACKED_URLS_FILE"; then
            log "Image URL already downloaded: $image_url"
            continue
        fi

        log "Downloading from Reddit: $image_url"
        if download_and_format_image "$image_url"; then
            echo "$image_url" >> "$TRACKED_URLS_FILE"
            return 0
        fi
    done

    return 1
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

# Function to select random wallpaper
random_wallpaper() {
    sanitize_filenames
    ensure_swww_daemon_running
    local files=("$WPATH"/wallpaper_*.png)
    if (( ${#files[@]} > 0 )); then
        local random_idx=$(( RANDOM % ${#files[@]} ))
        local selected_wallpaper="${files[random_idx]}"
        log "Selected random wallpaper: $selected_wallpaper"
        set_wallpaper "$selected_wallpaper"
    else
        log "No valid wallpapers found in $WPATH"
    fi
}

# Function to initialize wallpaper from the cache
init_wallpaper() {
    if [ -f "$CACHE_FILE" ]; then
        local file_path
        file_path=$(cat "$CACHE_FILE")
        set_wallpaper "$file_path"
    else
        log "No wallpaper cached to initialize."
    fi
}

# Function to update user image in power menu using Rofi
update_user_image() {
    log "Select an image to update the user image..."
    local files=($(ls "$WPATH"/*.png | sort -V))
    if [ ${#files[@]} -eq 0 ]; then
        log "No user images found in $WPATH"
        exit 1
    fi

    local options=""
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        options="$options\n$filename\0icon\x1f$file"
    done

    local selected_img
    selected_img=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -i -p "Select user image:" -no-custom)
    if [ -z "$selected_img" ]; then
        log "No image selected."
        exit 1
    elif [ -f "$WPATH/$selected_img" ]; then
        cp "$WPATH/$selected_img" "$USER_IMAGE"
        log "User image updated to $WPATH/$selected_img"
    else
        log "Selected file is not valid."
    fi
}

# Function to select wallpaper with Rofi
select_wallpaper() {
    local files=($(ls "$WPATH"/*.png | sort -V))
    if [ ${#files[@]} -eq 0 ]; then
        log "No wallpapers found in $WPATH"
        exit 1
    fi

    local options=""
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        options="$options\n$filename\0icon\x1f$file"
    done

    local selected_file
    selected_file=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -i -p "Select wallpaper:" -no-custom)
    if [ -z "$selected_file" ]; then
        log "No wallpaper selected"
        exit 1
    fi

    set_wallpaper "$WPATH/$selected_file"
}

# Function to change wallpaper at intervals
change_wallpaper_periodically() {
    local interval=$1
    while true; do
        random_wallpaper
        log "Wallpaper will change again in $interval seconds."
        sleep "$interval"
    done
}

# Function to update SDDM image manually
update_sddm_image() {
    log "Select an image to update the SDDM wallpaper..."
    local files=($(ls "$WPATH"/*.png | sort -V))
    if [ ${#files[@]} -eq 0 ]; then
        log "No SDDM images found in $WPATH"
        exit 1
    fi

    local options=""
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        options="$options\n$filename\0icon\x1f$file"
    done

    local selected_img
    selected_img=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -i -p "Select SDDM wallpaper:" -no-custom)
    if [ -z "$selected_img" ]; then
        log "No image selected."
        exit 1
    elif [ -f "$WPATH/$selected_img" ]; then
        log "Updating SDDM wallpaper with $WPATH/$selected_img"
        sudo rm /usr/share/sddm/themes/Sweet/current_wallpaper.png
        sudo cp "$WPATH/$selected_img" /usr/share/sddm/themes/Sweet/current_wallpaper.png
        log "SDDM wallpaper updated successfully with $WPATH/$selected_img"
    else
        log "Selected file is not valid: $WPATH/$selected_img"
        exit 1
    fi
}

# Main execution logic
ensure_swww_daemon_running

case $1 in
    download)
        download_and_set_wallpaper ;;
    search)
        search_and_download_image ;;
    select)
        select_wallpaper ;;
    random)
        random_wallpaper ;;
    init)
        init_wallpaper ;;
    update_user_image)
        update_user_image ;;
    update_sddm_image)
        update_sddm_image ;;
    interval)
        if [[ -z $2 ]]; then
            echo "Usage: $0 interval <seconds>"
            exit 1
        fi
        change_wallpaper_periodically "$2" ;;
    *)
        echo "Usage: $0 {download|search|select|random|init|update_user_image|update_sddm_image|interval <seconds>}"
        exit 1 ;;
esac

