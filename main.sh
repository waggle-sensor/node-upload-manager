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
    upload_list="$1"

    if [ -z "${upload_list}" ]; then
        echo "must provide upload list"
        return 1
    fi

    rsync -av \
        --exclude '.tmp*' \
        --files-from="${upload_list}" \
        --remove-source-files \
        --partial-dir=.partial/ \
        --bwlimit=0 \
        "/uploads/" \
        "beehive-upload-server:~/uploads/"
    # TODO investigate this option more. was using previously but
    # not clear what it's doing. also don't want it to accidentally
    # attempt to remove dir shared by plugin pod.
    # --prune-empty-dirs
}

# NOTE since we sleep for 60s every batch, syncing 100K
# cached data files would take 100K/100/60 = ~16.7 hours
build_upload_list() {
    # add up to 100 data files in one upload batch
    (
        cd /uploads
    find . | awk '
        /.tmp/ {next}
        (n == 100) && !/data/ && !/meta/ {exit}
        /data/ {n++}
        {print}
    '
    )
}

attempt_cleanup_empty_dirs() {
    # NOTE --ignore-fail-on-non-empty does *not* actually remove a non-empty dir - it simply
    # suppressed the error message
    # NOTE /uploads tree uses /uploads/task/version/ts-shasum structure and
    # we only attempt to cleanup the ts-shasum dirs.
    timeout 10 find /uploads -mindepth 3 -maxdepth 3 | xargs rmdir --ignore-fail-on-non-empty
}

upload_files() {
    echo "attempting to cleanup empty dirs"
    if ! attempt_cleanup_empty_dirs; then
        echo "cleanup empty dirs failed - proceeding anyway"
    fi

    echo "building upload batch list"
    if ! build_upload_list > /tmp/upload_list; then
        fatal "failed to build upload batch list"
    fi

    # check if there are any files to upload *before* connecting and
    # authenticating with the server
    if ! grep -q -m1 data /tmp/upload_list; then
        echo "no data files to rsync"
        return 0
    fi

    echo "resolving upload server address"
    if ! resolve_upload_server_and_update_etc_hosts; then
        fatal "failed to resolve upload server and update /etc/hosts."
    fi

    echo "rsyncing files"
    if ! rsync_upload_files /tmp/upload_list; then
        echo "failed to rsync files"
        return 1
    fi
}

while true; do
    if upload_files; then
        touch /tmp/healthy
    fi
    sleep 3
done
