#!/bin/bash

# Get the information about the currently focused window
ACTIVE_WINDOW_INFO=$(hyprctl activewindow)

# Extract the ID of the currently focused window
WINDOW_ID=$(echo "$ACTIVE_WINDOW_INFO" | awk '/->/ {print $2}')

# Extract the floating status of the window
IS_FLOATING=$(echo "$ACTIVE_WINDOW_INFO" | awk '/floating/ {print $2}')

# Get the current pinned windows
PINNED_WINDOWS=$(hyprctl pins)

# Check if the window is already pinned
IS_PINNED=$(echo "$PINNED_WINDOWS" | grep -c "$WINDOW_ID")

# Debug output to see the extracted information
echo "Active Window Info: $ACTIVE_WINDOW_INFO"
echo "Extracted Window ID: $WINDOW_ID"
echo "Is Floating: $IS_FLOATING"
echo "Pinned Windows: $PINNED_WINDOWS"
echo "Is Pinned: $IS_PINNED"

# Make the window float if it is not already floating
if [ "$IS_FLOATING" -eq 0 ]; then
    hyprctl dispatch togglefloating activewindow
    echo "Window $WINDOW_ID set to floating."
fi

# Toggle pinning the window to all workspaces
if [ "$IS_PINNED" -eq 0 ]; then
    hyprctl dispatch pin activewindow
    echo "Window $WINDOW_ID pinned to all workspaces."
else
    hyprctl dispatch unpin activewindow
    echo "Window $WINDOW_ID unpinned from all workspaces."
fi

