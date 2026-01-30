#!/bin/bash

DELAY=0.1
TIMESTAMP=$(date +%s)

function check_shutter_speed() {
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
}

function wait_for_prompt() {
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
}


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

tmux new-session -s gphoto2_"$TIMESTAMP" -d 'gphoto2 --camera="'"$model"'" --port="'"$port"'" --filename %Y_%m_%d_%H_%M_%S_%n.ARW --shell'
tmux pipe-pane -t gphoto2_"$TIMESTAMP":0.0 -o "cat > /dev/shm/gphoto2_$TIMESTAMP.log"

tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/capturesettings/capturemode=Bracketing C 3.0 Steps 5 Pictures' C-m 'set-config /main/capturesettings/shutterspeed=1/80' C-m 'set-config /main/capturesettings/imagequality=RAW' C-m 'set-config /main/actions/bulb=0' C-m

check_shutter_speed 1/80
echo

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

tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=1' Enter

echo "Dumping photos..."
arw_amount=0
time while [ "$arw_amount" != 15 ]
do
    tmux send-keys -t gphoto2_"$TIMESTAMP" 'capture-tethered CAPTURECOMPLETE' Enter
    wait_for_prompt
    arw_amount=$(ls -1 *.ARW | wc -l)
done

echo
echo "Photos dumped, stopping gphoto2!"
echo
tmux send-keys -t gphoto2_"$TIMESTAMP" 'set-config /main/actions/bulb=0' C-m 'exit' C-m

rm /dev/shm/gphoto2_$TIMESTAMP.log
