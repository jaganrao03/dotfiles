#!/bin/bash

# Function to check recording status and output JSON for waybar
check_recording_status() {
    pgrep wf-recorder >/dev/null 2>&1
    pgrep_exit_code="$?"

    recording="false"
    if [[ "$pgrep_exit_code" == "0" ]]; then
        recording="true"
    fi

    jq --unbuffered \
       --compact-output \
       --null-input \
       --arg recording "$recording" \
       '{ text: "recording-status", alt: $recording }'
}

# Get the correct output name
output=$(hyprctl monitors | awk '/Monitor/{print $2}' | head -n 1)
if [ -z "$output" ]; then
    notify-send "No monitor found" -i ~/.config/dunst/icons/recorder/error.png -r 9991
    exit 1
fi

# Check and create the directory for recordings if it does not exist
DIR="/home/jagan/Videos/Recordings"
if [ ! -d "$DIR" ]; then
    mkdir -p "$DIR"
fi

# Set the correct audio source
#audio_source="alsa_output.pci-0000_07_00.6.analog-stereo.monitor"
audio_source="alsa_output.usb-Apple__Inc._USB-C_to_3.5mm_Headphone_Jack_Adapter_DWH133500KMJKLTA0-00.analog-stereo.monitor"

# Main script to start or stop recording
VID="$DIR/$(date +'recording_%Y-%m-%d_%H-%M-%S').mkv"
pid="$(pgrep wf-recorder)"
pgrep_exit_code="$?"

if [ "$pgrep_exit_code" != "0" ]; then
    notify-send "Recording Started..." -i ~/.config/dunst/icons/recorder/recording.png -r 9991
    wf-recorder -a -o "$output" -f "$VID" --audio="$audio_source" &
else
    notify-send "Stopping recording..." -i ~/.config/dunst/icons/recorder/save.png -r 9991
    pkill --signal SIGINT wf-recorder
    while pgrep wf-recorder; do
        sleep 0.1
    done
    if [ -f "$VID" ]; then
        notify-send "Recording saved" "Saved as file $VID" -i ~/.config/dunst/icons/recorder/save.png -r 9991
    else
        notify-send "Recording failed" "Could not find video file" -i ~/.config/dunst/icons/recorder/error.png -r 9991
    fi
fi

pkill -RTMIN+2 waybar

# Check recording status
check_recording_status

