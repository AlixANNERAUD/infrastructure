#!/bin/sh
# Make a CrowdSec centralized allowlist hold exactly the given ranges, creating
# it when missing. Runs inside the CrowdSec container, read from stdin:
#   docker exec -i crowdsec sh -s -- <name> <description> <range>... < allowlist.sh
# Prints "changed" when it created, added or removed anything.
set -eu

name=$1
description=$2
shift 2
changed=false

if ! cscli allowlists inspect "$name" > /dev/null 2>&1; then
    cscli allowlists create "$name" --description "$description"
    changed=true
fi

# Raw output is CSV: name,description,value,comment,expiration,created_at,console_managed
current=$(cscli allowlists inspect "$name" -o raw | tail -n +2 | cut -d, -f3)

for range in "$@"; do
    if ! printf '%s\n' "$current" | grep -qxF "$range"; then
        cscli allowlists add "$name" "$range"
        changed=true
    fi
done

for value in $current; do
    wanted=false
    for range in "$@"; do
        if [ "$value" = "$range" ]; then
            wanted=true
        fi
    done
    if [ "$wanted" = false ]; then
        cscli allowlists remove "$name" "$value"
        changed=true
    fi
done

if [ "$changed" = true ]; then
    echo changed
fi
