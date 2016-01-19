#!/bin/bash
NODE_COUNT=$1
COMMAND="export IP_ADDR=\`ip a | tail -4 | head -1 | tr -s \" \" | cut -d\" \" -f3 | cut -d/ -f1\` && iex --name \\\"cohort@\$IP_ADDR\\\" --cookie test"

for NODE_ID in {1..$NODE_COUNT}
do
    docker run --name "misra-node-$NODE_ID" -t misra-token $COMMAND
done
