#!/bin/bash

. common.sh

if [ -z "$WAGGLE_NODE_ID" ]; then
    fatal "WAGGLE_NODE_ID is not defined"
fi

if [ -z "$WAGGLE_BEEHIVE_UPLOAD_HOST" ]; then
    fatal "WAGGLE_BEEHIVE_UPLOAD_HOST is not defined"
fi

if [ -z "$WAGGLE_BEEHIVE_UPLOAD_PORT" ]; then
    fatal "WAGGLE_BEEHIVE_UPLOAD_PORT is not defined"
fi

mkdir -p /root/.ssh/

# get username from ssh cert
username=$(ssh-keygen -L -f /etc/waggle/ssh-key-cert.pub | awk '/node-/ {print $1}')
echo "using username ${username}"

# define ssh config
cat <<EOF > /root/.ssh/config
Host beehive-upload-server
    Port ${WAGGLE_BEEHIVE_UPLOAD_PORT}
    User ${username}
    IdentityFile /etc/waggle/ssh-key
    CertificateFile /etc/waggle/ssh-key-cert.pub
    BatchMode yes
    ConnectTimeout 30
    LogLevel VERBOSE
EOF

if ! hostip=$(resolve_host_ip "$WAGGLE_BEEHIVE_UPLOAD_HOST"); then
    fatal "unable to resolve host ip for $WAGGLE_BEEHIVE_UPLOAD_HOST"
fi

echo "resolved $WAGGLE_BEEHIVE_UPLOAD_HOST to $hostip"

# workaround for "Host key verification failed" error
echo "$hostip beehive-upload-server" >> /etc/hosts

# define ssh known_hosts
if ! echo "@cert-authority beehive-upload-server $(cat /etc/waggle/ca.pub)" > /root/.ssh/known_hosts; then
    fatal "could not read CA certificate or create known_hosts file"
fi

while true; do
    # update heartbeat file for liveness probe
    touch /tmp/healthy

    # check if there are any files to upload *before* connecting and
    # authenticating with the server
    numfiles=$(find /uploads -type f | grep -v .tmp | wc -l)

    if [ $numfiles -gt 0 ]; then
        echo "rsyncing $numfiles file(s)"
        rsync -av \
        --exclude '.tmp*' \
        --remove-source-files \
        --partial-dir=.partial/ \
        --bwlimit=0 \
        "/uploads/" \
        "beehive-upload-server:~/uploads/"
    else
        echo "no files to rsync"
    fi

    sleep 60
done
