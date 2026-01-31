#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step (except for functions).
#trap read debug

# Mark III cameras have both Micro USB and USB-C ports. But Micro USB port is also used for
# remote shutter release! As it turned out - we can connect computer to USB-C and Micro USB
# to an external controller at the same time. And so, I've decided to try this hybrid approach,
# where USB-C is used for configuration and Micro USB to trigger the bracketing sequences.
# What about data? I've decided to try and skip the mandatory dumping to PC, writing to SD
# only. To achieve this we need to disconnect the camera from USB-C before taking the shots.
# To pull this off I've used a 3rd party device called Ykush XS. Learn more about it here:
# https://www.yepkit.com/product/300115/YKUSHXS
# For more details about the external controller - check out diy_usb_remote_shutter_trigger folder.

# Here we are creating a file to store any potential errors thrown by the serial connection.
SERIAL_DBG_PATH=$(echo "/dev/shm/eclipse_debug_"$(date +'%s'))
# To be honest, I don't remember why it's not 0.
DELAY=0.2
# This is to ensure that the camera has enough time to initialize after
# disconnecting/connecting to USB port of the computer.
YKUSH_DELAY=1.2


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
        # date
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

# First we trigger the shutter release, so the camera shoots the brscketing sequence.
# Afterwards we sleep for the amount which is a difference between first and second parameters.
# The conditional is set to handle first and second sequences. It will connect back the camera
# to USB, wait a bit, then issue a command to update the shutter speed. Lastly, it will
# disconnect the camera from USB and wait a bit.
function shoot_sequence() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!

    echo
    send_command $1
    echo "Waiting for frames to be saved to SD..."
    sleep $(echo "scale=6; $2-$1" | bc)
    echo
    echo "Done!"
    echo
    if [ "$3" != "" ]
    then
        ykushcmd ykushxs -u
        sleep $YKUSH_DELAY
        gphoto2 --set-config-value=/main/capturesettings/shutterspeed=$3
        check_shutter_speed $3
        ykushcmd ykushxs -d
        sleep $YKUSH_DELAY
    fi

    #trap - debug
}


echo "!!! This script is assuming that you've already set 'File Format' to 'RAW' !!!"
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

# Issue a command to Ykush XS to disconnect camera from USB and wait for a bit.
ykushcmd ykushxs -d
sleep $YKUSH_DELAY

# Here we shoot all 3 sequences. First parameter they send is the duration in seconds
# for the sum of all 5 shots taking during the bracketing sequence. The second parameter
# is the estimated duration of how much time camera needs to write to SD card.
# And the last parameter is the shutter speed for the next sequence, if there is one.
time shoot_sequence 0.913 5.0 1/40
time shoot_sequence 1.828 5.0 1/20
time shoot_sequence 3.656 6.2

# Issue a command to Ykush XS to connect camera to USB and wait for a bit.
ykushcmd ykushxs -u
sleep $YKUSH_DELAY

echo
echo "Stopping connection to serial"
kill $serial_pid
