#!/bin/bash
cp ../lib/misra.ex ./
sudo docker build -t misra-token --rm=true .
