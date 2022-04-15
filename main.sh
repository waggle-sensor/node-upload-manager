#!/bin/bash
set -eu

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

# ensure ssh dirs exist
mkdir -p /root/.ssh/controlmasters

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
    ControlPath /root/.ssh/controlmasters/%h:%p:%r
    ControlMaster auto
    ControlPersist 1m
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

get_rsync_pids() {
    awk '/rsync/ {print $1}' /proc/[0-9]*/stat
}

get_rsync_io_stats() {
    for pid in $(get_rsync_pids | sort); do
        # add pid to differentiate multiple runs of rsync
        echo "${pid}:"
        cat "/proc/${pid}/io"
    done
}

# rsync_supervisor is intended to be run as a background proc
# and monitors io from rsync to make sure it's making progress
rsync_supervisor() {
    check_internal=10
    check_delay=15

    while true; do
        # compute io stat diffs
        h1=$(get_rsync_io_stats | sha1sum)
        sleep "${check_delay}"
        h2=$(get_rsync_io_stats | sha1sum)

        # check if io stats are stale
        if [ "$h1" = "$h2" ]; then
            echo "warning: rsync hasn't made progress in ${check_delay}s... sending interrupt!"
            # attempt to kill. it's possible this is empty, so don't exit if this fails.
            kill $(get_rsync_pids) &> /dev/null || true
        fi

        sleep "${check_internal}"
    done
}

attempt_to_cleanup_dir() {
    rmdir "${1}" || true &> /dev/null
}

# TODO decide if we want to move this into something other than just a
# background proc. some ideas:
# * livenessprobe
# * shared pid sidecar (wolfgang shared this with me: https://kubernetes.io/docs/tasks/configure-pod-container/share-process-namespace/)
rsync_supervisor &

filter_valid_paths() {
    # example:
    # /uploads/test-pipeline/0.2.8/1649746359093671949-a31446e4291ac3a04a3c331e674252a63ee95604/data
    awk -F/ '$4 ~ /[0-9]+-[0-9a-f]+/'
}

while true; do
    if ! resolve_upload_server_and_update_etc_hosts; then
        fatal "failed to resolve upload server and update /etc/hosts."
    fi

    echo "scanning and uploading files..."
    cd /uploads

    # NOTE(sean) upload data is mounted at /uploads with leaf files like:
    # path:  /uploads/test-pipeline/0.2.8/1649746359093671949-a31446e4291ac3a04a3c331e674252a63ee95604/data
    # depth:    0         1           2                      3                                           4
    find . -mindepth 3 -maxdepth 3 -type d | filter_valid_paths | while read -r dir; do
        if ! ls "${dir}" | grep -q .; then
            echo "skipping dir with no uploads: ${dir}"
            attempt_to_cleanup_dir "${dir}"
            continue
        fi

        echo "uploading: ${dir}"
        # ensure upload file parent dirs exists
        ssh beehive-upload-server "mkdir -p ~/uploads/${dir}/"
        rsync -av \
            --exclude '.tmp*' \
            --progress \
            --compress \
            --remove-source-files \
            --itemize-changes \
            --partial-dir=.partial/ \
            --bwlimit=0 \
            "${dir}/" \
            "beehive-upload-server:~/uploads/${dir}/"
        attempt_to_cleanup_dir "${dir}"
        echo "done: ${dir}"

        # indicate that we are healthy and making progress after each transfer completes
        touch /tmp/healthy
    done

    # indicate that we are healthy and making progress, even if no files needed to be uploaded
    touch /tmp/healthy

    echo "uploaded all files found"
    sleep 10
done
