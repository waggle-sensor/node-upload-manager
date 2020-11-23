#!/bin/bash

# the agent will rsync files between the following locations:
# /uploads/plugin-name/... -> beehive:/home/node-id/plugin-name/...
#
# this allows us to maintain which node and plugin produced the data.

fatal() {
    echo $*
    exit 1
}

if [ -z "$WAGGLE_NODE_ID" ]; then
    fatal "WAGGLE_NODE_ID is not defined"
fi

if [ -z "$WAGGLE_UPLOAD_HOST" ]; then
    fatal "WAGGLE_UPLOAD_HOST is not defined"
fi

if ! echo "@cert-authority * $(cat /etc/waggle/ca.pub)" > /etc/ssh/ssh_known_hosts; then
    fatal "could not read CA certificate or create known_hosts file"
fi

# safety sleep to prevent runaway rsync during restart loop
sleep 10

while true; do
    rsync -a \
    -e "ssh -i /etc/waggle/ssh-key -o BatchMode=yes" \
    --exclude '.tmp*' \
    --remove-source-files \
    --partial-dir=.partial/ \
    --timeout=120 \
    --bwlimit=0 \
    "/uploads/" \
    "node${WAGGLE_NODE_ID}@${WAGGLE_UPLOAD_HOST}:~/uploads/"

    sleep 60
done
