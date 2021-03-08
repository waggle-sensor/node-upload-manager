#!/bin/bash

. common.sh

if ! resolve_host_ip 1.1.1.1 | grep 1.1.1.1; then
    fatal "should have resolved hoost ip 1.1.1.1"
fi

if ! resolve_host_ip google.com; then
    fatal "should be able to resolve google.com"
fi

if resolve_host_ip google1393-host-should-fail.com; then
    fatal "expected google1393-host-should-fail.com to fail"
fi
