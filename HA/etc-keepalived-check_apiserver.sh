#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

# Check VIP address
curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q 172.16.174.37; then
    curl --silent --max-time 2 --insecure https://172.16.174.37:6443/ -o /dev/null || errorExit "Error GET https://172.16.174.37:6443/"
fi
