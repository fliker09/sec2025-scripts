#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step (except for functions).
#trap read debug

# Mark III cameras have both Micro USB and USB-C ports. But Micro USB port is also used for
# remote shutter release! As it turned out - we can connect computer to USB-C and Micro USB
# to an external controller at the same time. And so, I've decided to try this hybrid approach,
# where USB-C is used for configuration & data and Micro USB to trigger the bracketing sequences.
# For more details about the external controller - check out diy_usb_remote_shutter_trigger folder.

# Here we are creating a file to store any potential errors thrown by the serial connection.
SERIAL_DBG_PATH=$(echo "/dev/shm/eclipse_debug_"$(date +'%s'))
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

# Mark III has a different behavior compared to Mark I and II, triggering two CAPTURECOMPLETE
# events, throwing off '--capture-tethered', which is why we can't use waiting time. Instead,
# we just run the command twice and use CAPTURECOMPLETE as the exit criteria. Not an elegant
# solution, but it is what it is. As for why we have 2 scenarios... The issue just described
# applies only when we shoot the last sequence. The first two sequences work the regular way.
# And we also don't need to adjust the shutter speed after the last sequence.
function run_tether() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!
    if [ "$1" == "" ]
    then
        gphoto2 --capture-tethered=CAPTURECOMPLETE --filename %Y_%m_%d_%H_%M_%S_%n.JPG
        gphoto2 --capture-tethered=CAPTURECOMPLETE --filename %Y_%m_%d_%H_%M_%S_%n.JPG
    else
        gphoto2 --capture-tethered=CAPTURECOMPLETE --filename %Y_%m_%d_%H_%M_%S_%n.JPG --set-config-value=/main/capturesettings/shutterspeed=$1
        echo
        check_shutter_speed $1
        echo
    fi
    #trap - debug
}

# We need to "open" a channel to our DIY USB shutter trigger before we can send any commands to it.
# Note: not friendly in an environment where multiple such controllers are connected!
# To handle such setups, one needs a more advanced approach.
function initiate_serial() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!

    echo "Initiating connection to serial"
    echo
    while [ ! -e /dev/shm/eclipse_serial ]
    do
        cat $(ls -1 /dev/ttyUSB* | tail -1) 2>$SERIAL_DBG_PATH
        sleep 0.1
    done

    #trap - debug
}

# This function is meant for sending commands to our external controller.
# It has a secondary purpose of checking the connection to it.
# It can report back if the connection has issues (not connected/throwing errors).
function send_command() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!

    if  [ -e $(ls -1 /dev/ttyUSB* | tail -1) ] && [ "$(cat $SERIAL_DBG_PATH 2>&1)" == "" ]
    then
        date
        if [ $1 == Checking ]
        then
            echo "Serial seems to be connected!"
            echo
        else
            echo "Shooting the sequence!"
            echo
            echo 1 > $(ls -1 /dev/ttyUSB* | tail -1)
            sleep $1
            echo 0 > $(ls -1 /dev/ttyUSB* | tail -1)
            echo "Done!"
            echo
        fi
    else
        echo "Something wrong with serial connection!"
        echo
        return 1
    fi

    #trap - debug
}

# A meta-function meant to handle the cases when the connection to the external controller
# is failing. It gives a chance to re-connect it and try again.
function serial_wrapper() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!

    for i in 1 2 3
    do
        send_command $1
        send_stat=$?
        if [[ $i == 3 && $send_stat != 0 ]]
        then
            echo "FAILURE TO SEND COMMAND! ABORTING!"
            echo
            exit_sequence
            exit 1
        fi
        if [ $send_stat == 0 ]
        then
            break
        else
            echo "You have 10 seconds to re-connect the serial cable! (attempt $i out of 2)"
            echo
            sleep 10
        fi
    done

    #trap - debug
}

# We launch into background (thanks to '&') the run_tether() function to dump the photos.
# By running it in parallel, we basically emulate what gphoto2 is regularly doing
# when it's the one triggering the shots. We record its process ID, so we wait on it
# to finish before exiting this function. And we also trigger the sequence through
# serial connection. This is how the hybrid approach is implemented.
function shoot_sequence() {
    run_tether $2 &
    tether_pid=$!
    sleep 0.2
    send_command $1
    wait $tether_pid
}


echo "!!! This script is assuming that you've already set 'File Format' to 'RAW & JPEG' !!!"
echo "It is also assumed that JPEG settings and PC Remote Settings have been configured as well."
echo "Please refer to the screenshots in the raw_jpeg_mode_settings subfolder!"
echo

# We intialize the connection to the external controller and send it to the background with '&'.
# We also store the process ID for this function, so we can stop it at the end of the script.
initiate_serial &
serial_pid=$!

# INFO: 'time' is used to measure the execution time (see the 'real' value).
# Set the starting shutter speed and Bracketing Continuous mode.
# This may take a while, depending on what settings you had before starting this script.
# For easier and consistent benchamarking please use prepare_usb.sh script!
time gphoto2 --set-config-value=/main/capturesettings/capturemode="Bracketing C 3.0 Steps 5 Pictures" --set-config-value=/main/capturesettings/shutterspeed=1/80
echo
# Ensure that Shutter Speed was indeed set at the desired value, as it's not guaranteed in one try.
time check_shutter_speed 1/80
echo
# Ensure that Bracketing Continuous mode was properly set as well.
time for l in $(seq 1 10)
do
    curr_mode=$(gphoto2 --get-config=/main/capturesettings/capturemode | grep Current | cut -d ':' -f 2 | sed 's/^ //')
    echo "Bracketing C 3.0 Steps 5 Pictures" $curr_mode
    if [ "$curr_mode" != "Bracketing C 3.0 Steps 5 Pictures" ]
    then
        gphoto2 --set-config-value=/main/capturesettings/capturemode="Bracketing C 3.0 Steps 5 Pictures"
        sleep $DELAY
    else
        break
    fi
done
echo

# Check if the connection to the external controller is OK.
serial_wrapper Checking

# Here we shoot all 3 sequences. First parameter they send is the duration in seconds
# for the sum of all 5 shots taking during the bracketing sequence. The second parameter
# is the shutter speed for the next sequence, if there is one.
time shoot_sequence 0.913 1/40
time shoot_sequence 1.828 1/20
time shoot_sequence 3.656

echo
echo "Stopping connection to serial"
kill $serial_pid
