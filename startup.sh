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
    sudo docker run -d --name "misra-node-$NODE_ID" -t misra-token /bin/bash -c '(export IP_ADDR=`ip a | tail -4 | head -1 | tr -s " " | cut -d" " -f3 | cut -d/ -f1` && iex --name "cohort@$IP_ADDR" --cookie test)'
done
IP_ADDRS=($(sudo docker ps | grep misra | tr -s ' ' | sort -k12 | cut -d' ' -f1 | xargs sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' | sed ':a;N;$!ba;s/\r\n/ /g'))
CONT_IDS=($(sudo docker ps | grep misra | tr -s ' ' | sort -k12 | cut -d' ' -f1))

function joinString { local IFS="$1"; shift; echo "[\"$*\"]"; }
function joinInt { local IFS="$1"; shift; echo "[$*]"; }

IPS=$(joinString "\", \"" "${IP_ADDRS[@]}")
IDS=$(joinInt ", " $(seq 0 $(($NODE_COUNT-1))))
NEXT_IPS=$(seq 1 $NODE_COUNT)

for i in $(seq 1 $NODE_COUNT)
do
    NEXT_IPS[$i] = ${IP_ADDRS[$(($i % $NODE_COUNT))]}
done
NEXT_IPS_STR=$(joinString "\", \"" "${NEXT_IPS[@]}")

iex -S mix run -e "MisraToken.coordStart $IDS, $IPS, $NEXT_IPS"
#for i in $(seq 1 $NODE_COUNT)
#do
    #echo "${CONT_IDS[(($i-1))]} -> ${IP_ADDRS[$(($i % $NODE_COUNT))]}"
#done

#iex -S mix -e ''
