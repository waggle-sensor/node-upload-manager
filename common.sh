#!/bin/bash

fatal() {
    echo $*
    exit 1
}

resolve_host_ip() {
    getent ahosts "$1" | awk '{ip=$1; exit} END {if (ip) { print ip } else { exit 1 }}'
}
