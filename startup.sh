#!/bin/bash
NODE_COUNT=$1
COMMAND=""

CONTS=$(sudo docker ps -a | grep misra | cut -d' ' -f1)
if [ ! -z "$CONTS" ]
then
    echo "$CONTS" | xargs sudo docker rm -f
fi

for NODE_ID in $(seq 1 $NODE_COUNT)
do
    sudo docker run -d --net="hydra0" --name="misra-node-$NODE_ID" -t misra-token /bin/bash -c '(export IP_ADDR=`ip a | tail -4 | head -1 | tr -s " " | cut -d" " -f3 | cut -d/ -f1` && epmd -daemon && iex --name "misra@$IP_ADDR" --cookie "test" -r "misra.ex")'
done
# --name "misra@$IP_ADDR

sleep 0.5

#IP_ADDRS=($(sudo docker ps | grep misra | tr -s ' ' | sort -k12 | cut -d' ' -f1 | xargs sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' | sed ':a;N;$!ba;s/\r\n/ /g'))
IP_ADDRS=($(sudo docker ps | grep misra | tr -s ' ' | sort -k12 | cut -d' ' -f1 | xargs sudo docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | sed ':a;N;$!ba;s/\r\n/ /g'))
CONT_IDS=($(sudo docker ps | grep misra | tr -s ' ' | sort -k12 | cut -d' ' -f1))

function joinString { local IFS="$1"; shift; echo "[\"$*\"]"; }
function joinInt { local IFS="$1"; shift; echo "[$*]"; }

IPS=$(joinString "," "${IP_ADDRS[@]}" | sed -e 's/,/\",\"/g')
IDS=$(joinInt "," $(seq 0 $(($NODE_COUNT-1))))
declare -a NEXT_IPS
declare -a NEXT_IDS

for ID in $(seq 1 $NODE_COUNT)
do
    NEXT_IPS[$(($ID-1))]=${IP_ADDRS[$(($ID % $NODE_COUNT))]}
    NEXT_IDS[$(($ID-1))]=$(($ID % $NODE_COUNT))
done
NEXT_IPS_STR=$(joinString "," "${NEXT_IPS[@]}" | sed -e 's/,/\",\"/g')
NEXT_IDS_STR=$(joinInt "," "${NEXT_IDS[@]}")

CMD="MisraToken.coordLoop $IDS,$IPS,$NEXT_IPS_STR,$NEXT_IDS_STR"
echo "cmd: '$CMD'"

iex --name "coordinator@172.18.0.1" --cookie test -S mix

