#!/bin/bash

# Configuration file path
config_file="$HOME/.config/hypr/hyprland.conf"

# Function to toggle monitor
toggle_monitor() {
    local monitor_name="$1"
    local monitor_enabled="monitor = $monitor_name, 1920x1200@120, 0x1440, 1"
    local monitor_disabled="monitor = $monitor_name, disable"

    echo "Checking current state for $monitor_name..."
    echo "Enabled pattern: '$monitor_enabled'"
    echo "Disabled pattern: '$monitor_disabled'"

    if grep -q "^$monitor_enabled" "$config_file"; then
        echo "Disabling monitor $monitor_name..."
        sed -i "s|^$monitor_enabled|$monitor_disabled|" "$config_file"
        notify-send "Hyprland" "Built-in monitor $monitor_name disabled."
    elif grep -q "^$monitor_disabled" "$config_file"; then
        echo "Enabling monitor $monitor_name..."
        sed -i "s|^$monitor_disabled|$monitor_enabled|" "$config_file"
        notify-send "Hyprland" "Built-in monitor $monitor_name enabled."
    else
        echo "Monitor configuration for $monitor_name not found."
    fi
}

# Get the list of all monitors from the Hyprland config
monitor_list=$(grep "^monitor = " "$config_file" | cut -d',' -f1 | cut -d' ' -f3)

# Loop through each monitor and toggle its state
for monitor_name in $monitor_list; do
    toggle_monitor "$monitor_name"
done

# Reload Hyprland configuration
hyprctl reload

# Debugging: Show the current state of the configuration file
echo "Current configuration:"
grep 'monitor = ' "$config_file"


