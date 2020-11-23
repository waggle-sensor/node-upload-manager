#!/bin/bash

# the agent will rsync files between the following locations:
# /uploads/plugin-name/... -> beehive:/home/node-id/plugin-name/...
#
# this allows us to maintain which node and plugin produced the data.

while true; do
    rsync -av \
    --exclude '.tmp*' \
    --remove-source-files \
    --stats \
    --partial-dir=.partial/ \
    --timeout=120 \
    --bwlimit=0 \
    /uploads/ \
    /remote/

    sleep 60
done
