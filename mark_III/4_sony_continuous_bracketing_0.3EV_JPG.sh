#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step (except for functions).
#trap read debug

# Unlike with 0.5EV step, there is no instability with 0.3EV step, so the value is set at 0.
DELAY=0.0


# This function checks the currently set shutter speed and if it matches the requested one.
# If it doesn't - it tries to set it to the requested value in 10 attempts at most.
function check_shutter_speed() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!
    sleep $DELAY
    for j in $(seq 1 10)
    do
        curr_exp=$(gphoto2 --camera="$model" --port="$port" --get-config=/main/capturesettings/shutterspeed | grep Current | cut -d ' ' -f 2)
        echo $curr_exp $1
        if [ "$curr_exp" != "$1" ]
        then
            gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/shutterspeed=$1
            sleep $DELAY
        else
            break
        fi
    done
    #trap - debug
}

echo "!!! This script is assuming that you've already set 'File Format' to 'RAW & JPEG' !!!"
echo "It is also assumed that JPEG settings and PC Remote Settings have been configured as well."
echo "Please refer to the screenshots in the raw_jpeg_mode_settings subfolder!"
echo

# An attempt to accelerate ever so slightly the gphoto2 commands,
# by making it not search for the available cameras. This piece of code
# just searches for the camera and stores its model name and USB port,
# so it can be re-used later in the script.
while IFS= read -r line; do
    # Trim leading/trailing whitespace
    line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Skip header and separator lines
    if [[ -z "$line" || "$line" =~ ^Model[[:space:]]+Port$ || "$line" =~ ^-+$ ]]; then
        continue
    fi

    # Extract port (last field)
    port="${line##* }"

    # Remove the port and trailing space to get the model
    model="${line% $port}"

    echo "Model: $model"
    echo "Port: $port"
done < <(gphoto2 --auto-detect)
echo

# INFO: 'time' is used to measure the execution time (see the 'real' value).
# Set the starting shutter speed and Bracketing Continuous mode.
# This may take a while, depending on what settings you had before starting this script.
# For easier and consistent benchamarking please use prepare_usb.sh script!
time gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/capturemode="Bracketing C 3.0 Steps 5 Pictures" --set-config-value=/main/capturesettings/shutterspeed=1/80
echo
# Ensure that Shutter Speed was indeed set at the desired value, as it's not guaranteed in one try.
time check_shutter_speed 1/80
echo
# Ensure that Bracketing Continuous mode was properly set as well.
time for l in $(seq 1 10)
do
    curr_mode=$(gphoto2 --camera="$model" --port="$port" --get-config=/main/capturesettings/capturemode | grep Current | cut -d ':' -f 2 | sed 's/^ //')
    echo "Bracketing C 3.0 Steps 5 Pictures" $curr_mode
    if [ "$curr_mode" != "Bracketing C 3.0 Steps 5 Pictures" ]
    then
        gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/capturemode="Bracketing C 3.0 Steps 5 Pictures"
        sleep $DELAY
    else
        break
    fi
done
echo

# We are shooting an entire bracketing sequence in one go.
# To achieve this we are gonna use... bulb option! Yeah, weird, but on Sony cameras it
# emulates shutter release button being pressed. The value is in seconds and can only be an integer.
# The values had to be found experimentally for each sequence. We must dump the photos right away!
# Thankfully, this happens as soon as a shot is taken. And right after, we set the shutter speed
# for the next bracketing sequence, saving time. No, the setting is not changed during the shooting,
# it waits for the sequence to finish first. %n is important, as we will dump multiple shots in the
# same second, which would get overwritten in succession otherwise!
time gphoto2 --camera="$model" --port="$port" --filename %Y_%m_%d_%H_%M_%S_%n.JPG --bulb 1 --capture-image-and-download --set-config-value=/main/capturesettings/shutterspeed=1/40
echo
time check_shutter_speed 1/40
echo

time gphoto2 --camera="$model" --port="$port" --filename %Y_%m_%d_%H_%M_%S_%n.JPG --bulb 2 --capture-image-and-download --set-config-value=/main/capturesettings/shutterspeed=1/20
echo
time check_shutter_speed 1/20
echo

# We don't set shutter speed for the next sequence here because... there is no next sequence :)
time gphoto2 --camera="$model" --port="$port" --filename %Y_%m_%d_%H_%M_%S_%n.JPG --bulb 5 --capture-image-and-download
echo
