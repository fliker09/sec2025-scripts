#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step.
#trap read debug


# Unlike with Mark I and II - no REST API initialization is required!
# We start one big cycle, which will take a shot for each desired shutter speed.
# There is a difference how we call the longer exposures. It's weird, but it is what it is!
for i in '3.2\"' '1.6\"' '0.8\"' '0.4\"' 1/5 1/10 1/20 1/40 1/80 1/160 1/320 1/640 1/1250 1/2500 1/5000
do
    # We will take up to 10 attempts for setting the shutter speed.
    # Yeah, it sometimes not succeeding on the first try :)
    for j in $(seq 1 10)
    do
        echo "Setting the shutter speed to $i"
        echo
        result=$(curl -s --location --request POST 'http://192.168.122.1:10000/sony/camera' --header 'Content-Type: application/json' --data-raw "{ \"id\": 1, \"method\": \"setShutterSpeed\", \"params\": [\"$i\"], \"version\": \"1.0\" }" | jq .result[] 2>&1)
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
    # We will take up to 10 attempts for taking a shot.
    # Yeah, it sometimes not succeeding on the first try :)
    # A neat feature here is that this call is synchronous,
    # which means it won't exit till the shot is done!
    for k in $(seq 1 10)
    do
        echo "Taking the shot..."
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
done
