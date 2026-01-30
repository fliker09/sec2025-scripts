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
# Set the starting shutter speed and Single Shot mode.
# This may take a while, depending on what settings you had before starting this script.
# For easier and consistent benchamarking please use prepare_usb.sh script!
time gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/shutterspeed=1/5000 --set-config-value=/main/capturesettings/capturemode="Single Shot"
echo
# Ensure that Shutter Speed was indeed set at the desired value, as it's not guaranteed in one try.
time check_shutter_speed 1/5000
echo
# Ensure that Single Shot mode was properly set as well.
time for l in $(seq 1 10)
do
    curr_mode=$(gphoto2 --camera="$model" --port="$port" --get-config=/main/capturesettings/capturemode | grep Current | cut -d ':' -f 2 | sed 's/^ //')
    echo "Single Shot" $curr_mode
    if [ "$curr_mode" != "Single Shot" ]
    then
        gphoto2 --camera="$model" --port="$port" --set-config-value=/main/capturesettings/capturemode="Single Shot"
        sleep $DELAY
    else
        break
    fi
done
echo

# Take 14x shots with 1EV step in succession. The last, 15th shot, will be taken after this cycle.
# It is done this way because:
# 1. We already configured the shutter speed for the first shot, so we want to shoot right away;
# 2. We don't need to waste time for shutter speed configuration after the last shot;
# 3. Accordingly, we don't need to ensure anything;
# 4. This is what we would like to do in real life - prepare ahead and shoot the entire sequence in rapid succession!
time for i in 1/2500 1/1250 1/640 1/320 1/160 1/80 1/40 1/20 1/10 1/5 4/10 8/10 16/10 32/10
do
    time gphoto2 --camera="$model" --port="$port" --trigger-capture --set-config-value=/main/capturesettings/shutterspeed=$i
    echo
    time check_shutter_speed $i
    echo
done
echo

# For the last, 15th shot, we just trigger the capture
time gphoto2 --camera="$model" --port="$port" --trigger-capture
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
