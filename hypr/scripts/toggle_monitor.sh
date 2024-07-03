#!/bin/bash

# Configuration file path
config_file="$HOME/.config/hypr/hyprland.conf"

# Monitor name to toggle
monitor_name="eDP-2"
monitor_enabled="monitor=$monitor_name,1920x1200@120,0x1440,1"
monitor_disabled="monitor=$monitor_name,disable"

# Check if the monitor is currently enabled or disabled
if grep -q "^$monitor_enabled" "$config_file"; then
    echo "Disabling monitor..."
    sed -i "s/^$monitor_enabled/$monitor_disabled/" "$config_file"
    notify-send "Hyprland" "Monitor $monitor_name disabled."
elif grep -q "^$monitor_disabled" "$config_file"; then
    echo "Enabling monitor..."
    sed -i "s/^$monitor_disabled/$monitor_enabled/" "$config_file"
    notify-send "Hyprland" "Monitor $monitor_name enabled."
else
    echo "Monitor configuration not found. Adding enabled monitor line..."
    echo "$monitor_enabled" >> "$config_file"
    notify-send "Hyprland" "Monitor $monitor_name enabled by default."
fi

# Reload Hyprland configuration
hyprctl reload

