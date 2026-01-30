#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step (except for functions).
#trap read debug

# This script was a wild experiment - what if we launched gphoto2 only once and run all the comands
# through that single instance? Yes, that is possible, as gphoto2 does support shell mode!
# To interact with that shell, 'tmux' was chosen as intermediary ('screen' proved to be too slow).
# The experiment turned out to be a success, it's the fastest among all the scripts!

# We need a delay for gphoto2's shell reading.
DELAY=0.1
# Provide an unique suffix for the launched instance, based on the epoch time in microseconds.
TIMESTAMP=$(date +%s%3N)


# This function checks the currently set shutter speed and if it matches the requested one.
# If it doesn't - it tries to set it to the requested value in 10 attempts at most.
# This itteration is more complex due to the use of gphoto2's shell and tmux to interact with it.
function check_shutter_speed() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!
    wait_for_prompt
    for j in $(seq 1 10)
    do
        tmux send-keys -t gphoto2_"$TIMESTAMP" 'get-config /main/capturesettings/shutterspeed' Enter
        wait_for_prompt
        curr_exp=$(grep Current /dev/shm/gphoto2_"$TIMESTAMP".log | cut -d ' ' -f 2 | tr -d '\r' | tail -1)
        echo $curr_exp $1
        if [ "$curr_exp" != "$1" ]
        then
            tmux send-keys -t gphoto2_"$TIMESTAMP" "set-config /main/capturesettings/shutterspeed=$1" Enter
            wait_for_prompt
        else
            break
        fi
    done
    #trap - debug
}

# This function is basically checking for new output line in gphoto2's shell.
# It's time constrained through the use of 'for' cycle. The value of 1000 was
# not chosen for any specific reason and probably should be reduced.
function wait_for_prompt() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!
    for i in $(seq 1 1000)
    do
        last_line=$(tail -1 /dev/shm/gphoto2_"$TIMESTAMP".log | grep -E '/> $')
        if [ "$last_line" == "" ]
        then
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

# Start a gphoto2 shell in a tmux session and then make it output into a log file.
tmux new-session -s gphoto2_"$TIMESTAMP" -d 'gphoto2 --camera="'"$model"'" --port="'"$port"'" --filename %Y_%m_%d_%H_%M_%S_%n.JPG --shell'
tmux pipe-pane -t gphoto2_"$TIMESTAMP":0.0 -o "cat > /dev/shm/gphoto2_$TIMESTAMP.log"

# Set the starting shutter speed and Bracketing Continuous mode.
# This may take a while, depending on what settings you had before starting this script.
# For easier and consistent benchamarking please use prepare_usb.sh script!
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/capturesettings/capturemode=Bracketing C 3.0 Steps 5 Pictures' C-m 'set-config /main/capturesettings/shutterspeed=1/80' C-m 'set-config /main/actions/bulb=0' C-m
# Ensure that Shutter Speed was indeed set at the desired value, as it's not guaranteed in one try.
check_shutter_speed 1/80
echo
# Ensure that Bracketing Continuous mode was properly set as well.
for l in $(seq 1 10)
do
    tmux send-keys -t gphoto2_"$TIMESTAMP" 'get-config /main/capturesettings/capturemode' Enter
    wait_for_prompt
    curr_mode=$(grep Current /dev/shm/gphoto2_"$TIMESTAMP".log | cut -d ':' -f 2 | sed 's/^ //' | tr -d '\r' | tail -1)
    echo $curr_mode "Bracketing C 3.0 Steps 5 Pictures"
    if [ "$curr_mode" != "Bracketing C 3.0 Steps 5 Pictures" ]
    then
        tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/capturesettings/capturemode=Bracketing C 3.0 Steps 5 Pictures' Enter
        wait_for_prompt
    else
        break
    fi
done
echo

# We can emulate keypress into tmux's session. Through this we are sending commands
# into gphoto2's shell. As we can see - we need to send bulb commands in a way
# which basically emulates real life pressing on shutter release button. Neat, right?!
# In a similar way we order it to adjust shutter speed for the next sequence.
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=1' Enter
sleep 1
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=0' Enter
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/capturesettings/shutterspeed=1/40' Enter
check_shutter_speed 1/40
echo

tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=1' Enter
sleep 1.9
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=0' Enter
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/capturesettings/shutterspeed=1/20' Enter
check_shutter_speed 1/20
echo

# Here we "click" on the proverbial shutter release button and... keep it that way, for now.
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=1' Enter

# Thanks to the command above, the sequence which includes the 3.2s exposure is underway.
# As we already know, Sony cameras allow file dumping to happen in parallel
# to shooting, so we will take advantage of it and start exactly that!
# Note: this can actually be used to benchmark file transfer speed, as there is no
# time wasted on initialiation and stuff. This should be pretty accurate approach!
echo "Dumping photos..."
jpg_amount=0
time while [ "$jpg_amount" != 15 ]
do
    tmux send-keys -t gphoto2_"$TIMESTAMP" 'capture-tethered CAPTURECOMPLETE' Enter
    wait_for_prompt
    jpg_amount=$(ls -1 *.JPG | wc -l)
done

echo
echo "Photos dumped, stopping gphoto2!"
echo
# Once the shots are dumped, we "unclick" the shutter release button and
# order gphoto2 shell to close up. After that we delete the log file.
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=0' C-m 'exit' C-m
rm /dev/shm/gphoto2_$TIMESTAMP.log
