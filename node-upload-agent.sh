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

SSH_CA_PUBKEY="${SSH_CA_PUBKEY:-/etc/waggle/ca.pub}"
SSH_KEY="${SSH_KEY:-/etc/waggle/ssh-key}"
SSH_CERT="${SSH_CERT:-/etc/waggle/ssh-key-cert.pub}"

echo "credential paths"
echo "ssh ca pubkey ${SSH_CA_PUBKEY}"
echo "ssh key ${SSH_KEY}"
echo "ssh cert ${SSH_CERT}"

# get username from ssh cert
username=$(ssh-keygen -L -f "${SSH_CERT}" | awk '/node-/ {print $1}')
echo "using username ${username}"

# define ssh config
cat <<EOF > /root/.ssh/config
Host beehive-upload-server
    Port ${WAGGLE_BEEHIVE_UPLOAD_PORT}
    User ${username}
    IdentityFile ${SSH_KEY}
    CertificateFile ${SSH_CERT}
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
if ! echo "@cert-authority beehive-upload-server $(cat ${SSH_CA_PUBKEY})" > /root/.ssh/known_hosts; then
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
