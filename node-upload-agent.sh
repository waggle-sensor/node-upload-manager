#!/bin/bash

while true; do
    rsync -av \
    --exclude '*.tmp' \
    --remove-source-files \
    --stats \
    --partial-dir=.partial/ \
    --timeout=120 \
    --bwlimit=0 \
    /uploads \
    /remote

    sleep 60
done
