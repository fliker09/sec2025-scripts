#!/bin/bash
# Alexandru Barbovschi (c) 2025-2026
# Uncomment the line below to show the execution of the script in full detail.
#set -x
# Uncomment the line below to execute the script step by step.
#trap read debug

# Unlike with Sony cameras, the options on Nikon cameras change pretty much instantly,
# eliminating the need emulate camera's state during the shooting of Baily'ds Beads,
# as it won't make much of a difference in execution time of this script.

# Configure a set of camera's options before proceeding with shooting.
# The inital shutter speed is set to the longest one - 3s.
# 'datetime=now' is an option not available with Sony cameras, sadly -
# it allows synchronizing the camera's time with the computer's.
# Right after it's done - we trigger the capture!
gphoto2 --set-config-value '/main/settings/capturetarget=Memory card' \
        --set-config-value '/main/imgsettings/iso=100' \
        --set-config-value '/main/capturesettings/shutterspeed=30/10' \
        --set-config-value '/main/capturesettings/f-number=f/5.6' \
        --set-config-value '/main/capturesettings/bracketing=Off' \
        --set-config-value '/main/settings/datetime=now' \
        --trigger-capture

# Now we go through the remaining 14 frames, in descending order!
# The trigger won't fire before the shitter speed is set, no worries here :)
for i in 16/10 8/10 4/10 1/5 1/10 1/20 1/40 1/80 1/160 1/320 1/640 1/1250 1/2500 1/4000
do
    echo $i
    gphoto2 --set-config-value "/main/capturesettings/shutterspeed=$i" --trigger-capture
    echo
done
