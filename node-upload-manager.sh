#!/bin/bash

while true; do
    rsync -av \
    --exclude '*.tmp' \
    --remove-source-files \
    /uploads \
    /remote

    sleep 60
done
