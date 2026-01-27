#!/bin/bash
# Uncomment the line below to show the execution of the script in full detail
#set -x
# Uncomment the line below to execute the script step by step
#trap read debug


# Before we can send any meaningful requests to the camera, we need to initiliaze the REST API
# There won't be a retry, just re-run the script if it didn't work first time
echo "Activating the remote mode on camera!"
result=$(curl -s --location --request POST 'http://192.168.122.1:8080/sony/camera' --header 'Content-Type: application/json' --data-raw '{ "id": 1, "method": "startRecMode", "params": [], "version": "1.0" }' | jq .result[])
if [ "$result" == 0 ]
then
    echo "All good!"
else
    echo "Something went wrong!"
fi
echo
