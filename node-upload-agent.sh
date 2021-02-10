#!/bin/bash

fatal() {
    echo $*
    exit 1
}

if [ -z "$WAGGLE_NODE_ID" ]; then
    fatal "WAGGLE_NODE_ID is not defined"
fi

# TODO Investigate how we should use BEEHIVE_UPLOAD_SERVER_SERVICE_HOST.
# By default, we'll assume beehive-upload-server exists in the DNS via
# a Kubernetes ExternalName Service or /etc/hosts.
#
# Currently, Kubernetes resolves this env var to an IP address and seem to
# mess up the host key check and shows this error:
# Certificate invalid: name is not a listed principal
# Host key verification failed.
#
# I've tried all comobnations of adding HostName ${BEEHIVE_UPLOAD_SERVER_SERVICE_HOST}
# to the ssh config and adding it as a principle to the known_hosts file. Removing it
# and just using beehive-upload-server is the only thing I found that works.
#
# if [ -z "$BEEHIVE_UPLOAD_SERVER_SERVICE_HOST" ]; then
#     fatal "BEEHIVE_UPLOAD_SERVER_SERVICE_HOST is not defined"
# fi

if [ -z "$WAGGLE_BEEHIVE_UPLOAD_PORT" ]; then
    fatal "WAGGLE_BEEHIVE_UPLOAD_PORT is not defined"
fi

mkdir -p /root/.ssh/

# get username from ssh cert
username=$(ssh-keygen -L -f /etc/waggle/ssh-key-cert.pub | awk '/node-/ {print $1}')

# define ssh config
cat <<EOF > /root/.ssh/config
Host beehive-upload-server
    Port ${BEEHIVE_UPLOAD_SERVER_SERVICE_PORT}
    User ${username}
    IdentityFile /etc/waggle/ssh-key
    CertificateFile /etc/waggle/ssh-key-cert.pub
    BatchMode yes
    ConnectTimeout 30
    LogLevel VERBOSE
EOF

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
