#!/bin/bash

# Path to your Hyprland config file
CONFIG_FILE=~/.config/hypr/hyprland.conf

# Function to send a notification
send_notification() {
    local message=$1
    notify-send "Hyprland Config" "$message"
}

# Function to change the user default browser
change_default_browser() {
    local new_browser=$1

    case "$new_browser" in
        "firedragon")
            xdg-settings set default-web-browser firedragon.desktop
            ;;
        "vivaldi")
            xdg-settings set default-web-browser vivaldi-stable.desktop
            ;;
        "firefox")
            xdg-settings set default-web-browser firefox.desktop
            ;;
        "floorp")
            xdg-settings set default-web-browser floorp.desktop
            ;;
        *)
            send_notification "Unsupported browser: $new_browser"
            return 1
            ;;
    esac
}

# Read current browser setting and toggle it
if grep -q 'browser = vivaldi' "$CONFIG_FILE"; then
    sed -i 's/browser = vivaldi/browser = firedragon/' "$CONFIG_FILE"
    change_default_browser "firedragon"
    send_notification "Default browser changed to Firedragon in Hyprland and user settings"
elif grep -q 'browser = firedragon' "$CONFIG_FILE"; then
    sed -i 's/browser = firedragon/browser = firefox/' "$CONFIG_FILE"
    change_default_browser "firefox"
    send_notification "Default browser changed to Firefox in Hyprland and user settings"
elif grep -q 'browser = firefox' "$CONFIG_FILE"; then
    sed -i 's/browser = firefox/browser = floorp/' "$CONFIG_FILE"
    change_default_browser "floorp"
    send_notification "Default browser changed to Floorp in Hyprland and user settings"
else
    sed -i 's/browser = floorp/browser = vivaldi/' "$CONFIG_FILE"
    change_default_browser "vivaldi"
    send_notification "Default browser changed to Vivaldi in Hyprland and user settings"
fi

# Optional: Restart Hyprland to apply changes
hyprctl reload

