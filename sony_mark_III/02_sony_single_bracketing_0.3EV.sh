#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step (except for functions).
#trap read debug

# Unlike with 0.5EV step, there is no instability with 0.3EV step, so the value is set at 0.
DELAY=0.0
# There is a need to introduce a static delay before
# we go for the next shot in the bracketing sequence.
# Below is the optimal value for Sony A7 III
WAIT_TIME=0.6


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

# We will shoot 3 bracketing sequences, so it's a good idea to have a function to fire them.
# That special clause for the longest duration exposure (which is the last one in the series)
# was added to avoid extra waiting time.
function take_frames() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!
    for i in $1
    do
        gphoto2 --camera="$model" --port="$port" --trigger-capture
        if [ "$i" != "32/10" ]
        then
            frame_delay=$(echo "scale=6; $i+$WAIT_TIME" | bc)
            echo $frame_delay
            sleep $frame_delay
        fi
    done
    #trap - debug
}


echo "!!! This script is assuming that you've already set 'File Format' to 'RAW' !!!"
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
# Set the starting shutter speed and Bracketing Single mode.
# This may take a while, depending on what settings you had before starting this script.
# For easier and consistent benchamarking please use prepare_usb.sh script!
time gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/capturemode="Bracketing S 3.0 Steps 5 Pictures" --set-config-value=/main/capturesettings/shutterspeed=1/80
echo
# Ensure that Shutter Speed was indeed set at the desired value, as it's not guaranteed in one try.
time check_shutter_speed 1/80
echo
# Ensure that Bracketing Single mode was properly set as well.
time for l in $(seq 1 10)
do
    curr_mode=$(gphoto2 --camera="$model" --port="$port" --get-config=/main/capturesettings/capturemode | grep Current | cut -d ':' -f 2 | sed 's/^ //')
    echo "Bracketing S 3.0 Steps 5 Pictures" $curr_mode
    if [ "$curr_mode" != "Bracketing S 3.0 Steps 5 Pictures" ]
    then
        gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/capturemode="Bracketing S 3.0 Steps 5 Pictures"
        sleep $DELAY
    else
        break
    fi
done
echo

# We are taking first 2 bracketing sequences in a regular way
time take_frames "1/80 1/640 1/10 1/5000 8/10"
echo
time gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/shutterspeed=1/40
echo
check_shutter_speed 1/40
echo
time take_frames "1/40 1/320 1/5 1/2500 16/10"
echo
time gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/shutterspeed=1/20
echo
check_shutter_speed 1/20
echo
# This final call looks like the ones above, but as we saw in the take_frames() function -
# for the last exposure we won't wait for camera to finish the shooting.
time take_frames "1/20 1/160 4/10 1/1250 32/10"
echo
# Now this one is a bit more tricky and was found experimentally.
# We are providing the pattern for the filename. %n is important, as we will get
# multiple shots in the same second, which would get overwritten in succession otherwise!
# The other option is triggering the dumping of all shots from camera's buffer.
# Unlike with Mark I and II, Mark III decided to make our lives harder. Instead of just setting it
# to wait for 15 seconds, we are forced to watch for a specific event. But! Once it's triggered
# gphoto2 exits... Which is why we are using a 'while' cycle and ensure all 15 shots are dumped.
# Note: the 3.2s exposure and file dumping will happen in parallel, which is perfect for us!
arw_amount=0
time while [ "$arw_amount" != 15 ]
do
    gphoto2 --camera="$model" --port="$port" --filename $(date +"%Y_%m_%d_%H_%M_%S_%3N")_%n.ARW --capture-tethered CAPTURECOMPLETE
    echo
    arw_amount=$(ls -1 *.ARW | wc -l)
done
