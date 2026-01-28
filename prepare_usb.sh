#!/bin/bash
# Uncomment the line below to show the execution of the script in full detail
#set -x
# Uncomment the line below to execute the script step by step (except for functions)
#trap read debug

# This might need adjustment, depending on exposre step, 0.5EV vs 0.3EV, as the former is unstable.
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
        curr_exp=$(gphoto2 --get-config=/main/capturesettings/shutterspeed | grep Current | cut -d ' ' -f 2)
        echo $curr_exp $1
        if [ "$curr_exp" != "$1" ]
        then
            gphoto2 --set-config-value=/main/capturesettings/shutterspeed=$1
            sleep $DELAY
        else
            break
        fi
    done
    #trap - debug
}


# Set the starting shutter speed and shooting mode.
# In this case we are simulating the state of the camera as it was shooting Baily's Beads.
gphoto2 --set-config-value=/main/capturesettings/capturemode="Continuous Low Speed" --set-config-value=/main/capturesettings/shutterspeed=1/8000
echo
# Ensure that Shutter Speed was indeed set at the desired value, as it's not guaranteed in one try.
check_shutter_speed 1/8000
echo
# Ensure that shooting mode was properly set as well.
for l in $(seq 1 10)
do
    curr_mode=$(gphoto2 --get-config=/main/capturesettings/capturemode | grep Current | cut -d ':' -f 2 | sed 's/^ //')
    echo "Continuous Low Speed" $curr_mode
    if [ "$curr_mode" != "Continuous Low Speed" ]
    then
        gphoto2 --set-config-value=/main/capturesettings/capturemode="Continuous Low Speed"
        sleep $DELAY
    else
        break
    fi
done
