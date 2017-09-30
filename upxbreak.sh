#!/bin/bash
declare q
q=$(cat /dev/urandom| tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
cat $1 | sed "s/UPX!/$q/g" > "$1.new"
