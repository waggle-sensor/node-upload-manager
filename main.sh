#!/bin/bash -e

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

echo "using credentials"
echo "ssh ca pubkey: ${SSH_CA_PUBKEY}"
echo "ssh key: ${SSH_KEY}"
echo "ssh cert: ${SSH_CERT}"

# get username from ssh cert
# TODO(sean) make this match more robust. output looks like:
# /etc/waggle/ssh-key-cert.pub:
#         Type: ssh-rsa-cert-v01@openssh.com user certificate
#         Public key: RSA-CERT SHA256:i5Orb/PHT1rM7Mq6mM/m366tnPVaIzGXDr0Ras9PRbE
#         Signing CA: RSA SHA256:XxSyeGs55EKetdO+31XLgz/fGbAk7v/S57ChRPhibgo (using rsa-sha2-256)
#         Key ID: "node-0000000000000001 ssh host key"
#         Serial: 0
#         Valid: from 2021-03-22T21:09:04 to 2022-03-22T21:14:04
#         Principals: 
#                 node-0000000000000001
#         Critical Options: (none)
#         Extensions: 
#                 permit-X11-forwarding
#                 permit-agent-forwarding
#                 permit-port-forwarding
#                 permit-pty
#                 permit-user-rc
username=$(ssh-keygen -L -f "${SSH_CERT}" | awk '$1 ~ /^node-/ {print $1}')
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

# NOTE workaround for "Host key verification failed" issue. at the moment, this seems to be because
# our upload server ssh cert uses name "beehive-upload-server". eventually, this should be updated
# to use the actual hostname of the upload server.

# create backup of original /etc/hosts file
# NOTE used by the resolve_upload_server_and_update_etc_hosts function below.
cp /etc/hosts /tmp/hosts

resolve_upload_server_and_update_etc_hosts() {
    if ! hostip=$(resolve_host_ip "$WAGGLE_BEEHIVE_UPLOAD_HOST"); then
        echo "unable to resolve host ip for $WAGGLE_BEEHIVE_UPLOAD_HOST"
        return 1
    fi

    echo "resolved $WAGGLE_BEEHIVE_UPLOAD_HOST to $hostip"

    if ! cat /tmp/hosts > /etc/hosts; then
        echo "failed to update /etc/hosts"
        return 1
    fi
    
    if ! echo "$hostip beehive-upload-server" >> /etc/hosts; then
        echo "failed to update /etc/hosts"
        return 1
    fi

    if ! echo "@cert-authority beehive-upload-server $(cat ${SSH_CA_PUBKEY})" > /root/.ssh/known_hosts; then
        echo "failed to update /root/.ssh/known_hosts"
        return 1
    fi
}

rsync_upload_files() {
    rsync -av \
        --exclude '.tmp*' \
        --prune-empty-dirs \
        --remove-source-files \
        --partial-dir=.partial/ \
        --bwlimit=0 \
        "/uploads/" \
        "beehive-upload-server:~/uploads/"
}

upload_files() {
    # check if there are any files to upload *before* connecting and
    # authenticating with the server
    numfiles=$(find /uploads -type f | grep -v .tmp | wc -l)
    
    if [ $numfiles -eq 0 ]; then
        echo "no files to rsync"
        return 0
    fi

    echo "resolving upload server address"
    if ! resolve_upload_server_and_update_etc_hosts; then
        echo "failed to resolve upload server and update /etc/hosts. retrying..."
        return 1
    fi

    echo "rsyncing $numfiles file(s)"
    if ! rsync_upload_files; then
        echo "failed to rsync files"
        return 1
    fi
}

while true; do
    if upload_files; then
        touch /tmp/healthy
    fi
    sleep 60
done
