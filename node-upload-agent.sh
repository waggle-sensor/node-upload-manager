#!/bin/bash

fatal() {
    echo $*
    exit 1
}

if [ -z "$WAGGLE_NODE_ID" ]; then
    fatal "WAGGLE_NODE_ID is not defined"
fi

if [ -z "$BEEHIVE_UPLOAD_SERVER_SERVICE_HOST" ]; then
    fatal "BEEHIVE_UPLOAD_SERVER_SERVICE_HOST is not defined"
fi

if [ -z "$BEEHIVE_UPLOAD_SERVER_SERVICE_PORT" ]; then
    fatal "BEEHIVE_UPLOAD_SERVER_SERVICE_PORT is not defined"
fi

mkdir -p /root/.ssh/

# define ssh config
cat <<EOF > /root/.ssh/config
Host beehive-upload-server
    HostName ${BEEHIVE_UPLOAD_SERVER_SERVICE_HOST}
    Port ${BEEHIVE_UPLOAD_SERVER_SERVICE_PORT}
    User node${WAGGLE_NODE_ID}
    IdentityFile /etc/waggle/ssh-key
    CertificateFile /etc/waggle/ssh-key-cert.pub
    BatchMode yes
    ConnectTimeout 30
    LogLevel VERBOSE
EOF

# define ssh known_hosts
if ! echo "@cert-authority * $(cat /etc/waggle/ca.pub)" > /root/.ssh/known_hosts; then
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
