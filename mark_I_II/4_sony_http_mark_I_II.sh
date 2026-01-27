#!/bin/bash
# Uncomment the line below to show the execution of the script in full detail
#set -x
# Uncomment the line below to execute the script step by step
#trap read debug


# You must first initiliaze the REST API on the camera, please run prepare_http.sh!
# We start one big cycle, which will take a shot for each desired shutter speed.
for i in 32/10 16/10 8/10 4/10 1/5 1/10 1/20 1/40 1/80 1/160 1/320 1/640 1/1250 1/2500 1/5000
do
    # We will take 10 attempts for setting the shutter speed.
    # Yeah, it sometimes not succeeding on the first try :)
    for j in $(seq 1 10)
    do
        echo "Setting the shutter speed to $i"
        echo
        result=$(curl -s --location --request POST 'http://192.168.122.1:8080/sony/camera' --header 'Content-Type: application/json' --data-raw "{ \"id\": 1, \"method\": \"setShutterSpeed\", \"params\": [\"$i\"], \"version\": \"1.0\" }" | jq .result[])
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
    echo "Taking the shot..."
    # Issue a command to take the shot!
    # A neat feature here is that this call is synchronous,
    # which means it won't exit till the shot is done!
    jpeg_url=$(curl -s --location --request POST 'http://192.168.122.1:8080/sony/camera' --header 'Content-Type: application/json' --data-raw '{ "id": 1, "method": "actTakePicture", "params": [], "version": "1.0" }' | jq -r .result[][])
    echo
    echo "Done!"
    echo
    # Uncomment the 3 lines below to see if the shooting went well and has the right shutter speed.
    # Please note that it will slow down the script, skewing the benchmark result.
    #wget "$jpeg_url"
    #exiftool $(ls -1 *.JPG | tail -1) | grep -i "shutter speed"
    #echo
done
