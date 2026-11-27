#!/bin/sh
# Unseals OpenBao with unseal keys that Bruxelles' TPM keeps sealed.
#
#   deverrouillage.sh           checks OpenBao every 30 seconds and unseals it
#                               when it is initialized and sealed
#   deverrouillage.sh sceller   reads unseal keys on standard input, one per
#                               line, and seals each one with the TPM
#
# Each sealed key is a TPM object (cle-<n>.pub and cle-<n>.priv in /cles),
# under a primary key that the TPM derives again from its owner seed at each
# use. The files are useless on another TPM, or after this TPM is cleared: the
# paper keys stay the reference, and unseal OpenBao anywhere. The unseal keys
# only exist in memory, and go to OpenBao in the body of a request (never in a
# process argument), over TLS to the holder of OpenBao's key.
set -eu

directory=/cles
work=/tmp/deverrouillage
name=${OPENBAO_NAME:?Set OPENBAO_NAME}
address="https://$name:8200"
# OpenBao's public key: its certificate is self-signed and expires after a
# year, its key does not change
public_key=/openbao.pem
export TPM2TOOLS_TCTI=device:/dev/tpmrm0

# The primary key under which the keys are sealed. The TPM derives the same
# key from the same template each time, so it is never stored. The template is
# written out (tpm2-tools 5.7's defaults, with ECC): a new tpm2-tools with other
# defaults would derive another key, which could not load the sealed keys
primary() {
    mkdir -p "$work"
    tpm2_createprimary -Q -C o -g sha256 -G ecc256:null:aes128cfb \
        -a 'restricted|decrypt|fixedtpm|fixedparent|sensitivedataorigin|userwithauth' \
        -c "$work/primary.ctx"
}

openbao() {
    curl --silent --show-error --fail --insecure --pinnedpubkey "$public_key" \
        --connect-to "$name:8200:openbao:8200" "$@"
}

seal() {
    primary
    rm -f "$work"/cle-*
    count=0
    echo "Type the unseal keys, one per line (they are not shown), then an empty line:" >&2
    # BusyBox's sh (Alpine) has read -s, which does not show what is typed
    # shellcheck disable=SC3045
    while IFS= read -r -s key && [ -n "$key" ]; do
        count=$((count + 1))
        printf '%s' "$key" | tpm2_create -Q -C "$work/primary.ctx" -i - \
            -u "$work/cle-$count.pub" -r "$work/cle-$count.priv"
        echo "Key $count sealed" >&2
    done
    key=
    if [ "$count" -eq 0 ]; then
        echo "No key typed: the sealed keys did not change" >&2
        exit 1
    fi
    # The new keys first go next to the old ones, which stay until then
    rm -rf "$directory/nouvelles"
    mkdir "$directory/nouvelles"
    mv "$work"/cle-* "$directory/nouvelles/"
    rm -f "$directory"/cle-*
    mv "$directory/nouvelles"/cle-* "$directory"/
    rmdir "$directory/nouvelles"
    echo "$count keys sealed in $directory" >&2
}

# Gives OpenBao one sealed key after the other, until it is unsealed. Returns
# 2 when OpenBao does not answer (it may still be starting), 1 when the TPM or
# OpenBao refuses a key
unseal() {
    if ! openbao --request PUT --data '{"reset": true}' "$address/v1/sys/unseal" > /dev/null; then
        return 2
    fi
    if ! primary; then
        echo "The TPM did not derive the primary key" >&2
        return 1
    fi
    for public in "$directory"/cle-*.pub; do
        if ! tpm2_load -Q -C "$work/primary.ctx" -u "$public" -r "${public%.pub}.priv" -c "$work/cle.ctx" \
            || ! key=$(tpm2_unseal -c "$work/cle.ctx"); then
            rm -f "$work/cle.ctx"
            echo "The TPM did not unseal $public: was it cleared, or replaced? Seal the keys again" >&2
            return 1
        fi
        rm -f "$work/cle.ctx"
        if ! answer=$(printf '%s' "$key" | jq --raw-input --compact-output '{key: .}' \
            | openbao --request PUT --data @- "$address/v1/sys/unseal"); then
            key=
            echo "OpenBao refused the key of $public" >&2
            return 1
        fi
        key=
        if [ "$(printf '%s' "$answer" | jq --raw-output .sealed)" = false ]; then
            echo "OpenBao is unsealed"
            return 0
        fi
    done
    echo "OpenBao is still sealed after every sealed key: seal more keys" >&2
    return 1
}

# Writes a message once, not every 30 seconds while the state lasts
last=
say() {
    if [ "$1" != "$last" ]; then
        echo "$1"
        last=$1
    fi
}

watch() {
    while :; do
        if ! state=$(openbao "$address/v1/sys/seal-status" 2> /dev/null); then
            say "OpenBao does not answer"
        elif [ "$(printf '%s' "$state" | jq --raw-output .initialized)" != true ]; then
            say "OpenBao is not initialized: run bao operator init"
        elif [ "$(printf '%s' "$state" | jq --raw-output .sealed)" != true ]; then
            say "OpenBao is unsealed"
        elif ! ls "$directory"/cle-*.pub > /dev/null 2>&1; then
            say "OpenBao is sealed and no key is sealed: run deverrouillage.sh sceller"
        else
            status=0
            unseal || status=$?
            if [ "$status" -eq 0 ]; then
                last="OpenBao is unsealed"
            elif [ "$status" -eq 1 ]; then
                # A refused key fails the same way each time: try again later
                last=
                sleep 300
            fi
        fi
        sleep 30
    done
}

case "${1:-}" in
    '') watch ;;
    sceller) seal ;;
    *)
        echo "Usage: deverrouillage.sh [sceller]" >&2
        exit 1
        ;;
esac
