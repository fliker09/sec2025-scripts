#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step (except for functions).
#trap read debug

# Unlike with Sony cameras, the options on Nikon cameras change pretty much instantly,
# eliminating the need emulate camera's state during the shooting of Baily'ds Beads,
# as it won't make much of a difference in execution time of this script.

# Sadly, I found no way to simulate a shutter release button pressing with gphoto2,
# so I had to resort to using an external controller and integrate its use here.
# You can check out it in the the diy_usb_remote_shutter_trigger folder.
# The overall code is quite different from the one used for Sony due to
# the fact that most of this was re-sued from the older sripts.

# Here we are creating a file to store any potential errors thrown by the serial connection.
SERIAL_DBG_PATH=$(echo "/dev/shm/eclipse_debug_"$(date +'%s'))


# We need to "open" a channel to our DIY USB shutter trigger before we can send any commands to it.
# Note: not friendly in an environment where multiple such controllers are connected!
# To handle such setups, one needs a more advanced approach.
initiate_serial()
    {
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
send_command()
    {
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
                echo
                echo "Shooting the sequence!"
                echo
                echo 1 > $(ls -1 /dev/ttyUSB* | tail -1)
                sleep $1
                echo 0 > $(ls -1 /dev/ttyUSB* | tail -1)
                echo "Done!"
            fi
        else
            echo "Something wrong with serial connection!"
            echo
            return 1
        fi

        #trap - debug
    }

# Check if the camera is connected or not. It assumes that only a single, Nikon, camera is connected!
# For multi-camera setups, a more advanced approach si required.
verify_camera_presence()
    {
        # Uncomment the line below to execute the function step by step
        #trap read debug
        # If you did uncomment the line above - uncomment the last line as well,
        # to limit this mode to this function alone!
        
        nikon_port=$(gphoto2 --auto-detect 2>/dev/null | grep usb | awk '{print $4}')

        if [ "$nikon_port" == "" ]
        then
            echo "Camera is not detected / connected!"
            echo
            return 1
        fi
        
        #trap - debug
    }

# This function is meant to be invoked at the end of the script, to gracefully terminate it.
# Currently it has 2 purposes - close the connection to the external controller
# and report the overall duration of the script's execution.
exit_sequence()
    {
        # Uncomment the line below to execute the function step by step
        #trap read debug
        # If you did uncomment the line above - uncomment the last line as well,
        # to limit this mode to this function alone!

        echo
        echo "Stopping connection to serial!"
        touch /dev/shm/eclipse_serial
        cat_pid=$(pgrep -f ttyUSB)
        kill $cat_pid
        wait
        rm /dev/shm/eclipse_serial
        rm $SERIAL_DBG_PATH

        end_time=$(date +%s)

        echo
        echo "Total duration: $(( $end_time - $start_time )) seconds"

        #trap - debug
    }

# A meta-function meant to handle the cases when the connection to the external controller
# is failing. It gives a chance to re-connect it and try again.
serial_wrapper()
    {
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


start_time=$(date +%s)

# We intialize the connection to the external controller and send it to the background with '&'.
initiate_serial &

# This basically does the same as serial_wrapper() function, but for camera instead.
for i in 1 2 3
do
    verify_camera_presence
    cam_stat=$?
    if [[ $i == 3 && $cam_stat != 0 ]]
    then
        echo "FAILED TO CONNECT CAMERA! ABORTING!"
        echo
        exit_sequence
        exit 1
    fi
    if [ $cam_stat == 0 ]
    then
        echo "Nikon camera port: $nikon_port"
        echo
        break
    else
        echo "You have 10 seconds to re-connect / restart Nikon camera! (attempt $i out of 2)"
        echo
        sleep 10
    fi
done

# Check and report the current battery level. This is also kind of an initialization for the camera.
bat_level=$(gphoto2 --port $nikon_port --get-config '/main/status/batterylevel' | sed -n 4p | cut -d ' ' -f 2)
echo "Current battery level is $bat_level"
echo

# Check if the connection to the external controller is OK.
serial_wrapper Checking

# Configure a set of parameters before proceeding with taking shots.
# 'd0c1' allows to choose the bracketing step (5 corresponds to 3EV).
# 'd0c2' instructs camera to shoot both under and over exposures.
# The meaning of both properties were found experimentally.
# 'datetime=now' is an option not available with Sony cameras, sadly -
# it allows synchronizing the camera's time with the computer.
echo "Configuring initial camera parameters! (detailed timings follow)"
time gphoto2 --port $nikon_port \
             --set-config-value '/main/settings/capturetarget=Memory card' \
             --set-config-value '/main/imgsettings/iso=100' \
             --set-config-value '/main/capturesettings/shutterspeed=4/10' \
             --set-config-value '/main/capturesettings/f-number=f/5.6' \
             --set-config-value '/main/capturesettings/bracketing=On' \
             --set-config-value '/main/capturesettings/bracketorder=MTR > Under' \
             --set-config-value '/main/other/d0c1=5' \
             --set-config-value '/main/other/d0c2=2' \
             --set-config-value '/main/settings/datetime=now'

# The golden staple of programming - a delay :D
# It allows camera to "settle" the freshly configured options.
sleep 0.2

# Engage the external controller to trigger the shutter release pressing!
# The parameter '5' is duration in seconds.
send_command 5

# Change the shutter speed in preparation for the next sequence.
time gphoto2 --port $nikon_port --set-config-value '/main/capturesettings/shutterspeed=1/5'

send_command 3

time gphoto2 --port $nikon_port --set-config-value '/main/capturesettings/shutterspeed=1/10'

send_command 2

# Here, beside changing the shutter speed, we also instruct to switch from 3EV to 2EV exposure step.
time gphoto2 --port $nikon_port --set-config-value '/main/capturesettings/shutterspeed=1/640' --set-config-value '/main/other/d0c1=4'

send_command 1

time gphoto2 --port $nikon_port --set-config-value '/main/capturesettings/shutterspeed=1/1250'

send_command 1

# We are done! Let's clean up, report the duration and exit the script!
exit_sequence
