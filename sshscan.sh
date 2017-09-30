#!/bin/bash
declare network
network=$(ifconfig -a | grep inet | grep broadcast | head -n 1| awk -F " " '{ print $2}' | awk -F "." '{print $1"."$2"."$3"."}')
seq -f "$network.%g" 0 255 > /tmp/range
ssh-keyscan -f /tmp/range &> $1
rm /tmp/range
