#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step (except for functions).
#trap read debug


# Unlike with Mark I and II - no REST API initialization is required!
# We use a function to run the bracketing sequences.
function shoot_sequence() {
    # Uncomment the line below to execute the function step by step
    #trap read debug
    # If you did uncomment the line above - uncomment the last line as well,
    # to limit this mode to this function alone!

    # We will take up to 10 attempts for setting the shutter speed.
    # Yeah, it sometimes not succeeding on the first try :)
    for j in $(seq 1 10)
    do
        echo "Setting the shutter speed to $1"
        echo
        result=$(curl -s --location --request POST 'http://192.168.122.1:10000/sony/camera' --header 'Content-Type: application/json' --data-raw "{ \"id\": 1, \"method\": \"setShutterSpeed\", \"params\": [\"$1\"], \"version\": \"1.0\" }" | jq .result[] 2>&1)
        if [ "$result" == 0 ]
        then
            echo "All good!"
            echo
            break
        else
            echo
            echo "Something went wrong! Trying again..."
            echo
        fi
    done
    # We will take up to 10 attempts for shooting bracketing sequence.
    # Yeah, it sometimes not succeeding on the first try :)
    for k in $(seq 1 10)
    do
        echo "Shooting the sequence..."
        echo
        output=$(curl -s --location --request POST 'http://192.168.122.1:10000/sony/camera' --header 'Content-Type: application/json' --data-raw '{ "id": 1, "method": "actTakePicture", "params": [], "version": "1.0" }' 2>&1)
        # Uncomment to check what exactly camera is returning, useful for debugging.
        #echo "$output"
        #echo
        jpeg_url=$(echo "$output" | jq -r .result[][] 2>/dev/null)
        if [ "$jpeg_url" != "" ]
        then
            echo "All good!"
            echo
            break 
        else
            echo "Something went wrong! Trying again..."
            echo
        fi
        # Uncomment the 3 lines below to see if the shooting went well and has the right shutter speed.
        # Please note that it will slow down the script, skewing the benchmark result.
        #wget "$jpeg_url"
        #exiftool $(ls -1 *.JPG | tail -1) | grep -i "shutter speed"
        #echo
    done
    # Unlike with Single Shot mode, this mode is asynchronous,
    # which is why we need to sleep, emulating shutter button pressing.
    # Sleep duration values have been found experimentally.
    sleep $2
    #trap - debug
}

echo "!!! This script is assuming that you've switched to the desired bracketing mode !!!"
echo

shoot_sequence 1/20 0
shoot_sequence 1/40 1
shoot_sequence 1/80 2
