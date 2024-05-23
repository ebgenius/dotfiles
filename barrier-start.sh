#!/bin/bash

IP_ADDRESS=$(ifconfig | grep -A1 'enp0s31f6' | tail -n1 | awk '{print $2}')
SERVER_NAME=$(hostname)

/usr/bin/barrierc --no-tray --debug INFO --name $SERVER_NAME $IP_ADDRESS

