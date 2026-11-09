#!/usr/bin/env bash
# Start Trousseau as services/trousseau/deploy.yml lays it out: its first
# start must initialize it and its static key unseal it. Apply
# opentofu/trousseau with the AppRole that first start creates (without the
# Zitadel login: no Zitadel here), twice, the second time with nothing to
# change. Then sign keys and log in with their certificates to an SSH server
# that trusts the users' authority and presents a host certificate: the
# owner's certificate logs in as alix_anneraud only, a bare key does not, and
# Ansible's certificate only works from its networks. Finally, a restart must
# unseal it again with its configuration kept.
set -euo pipefail

directory=$(mktemp -d)
project=check-trousseau-$$
network=$project-proxy
server=$project-ssh
seal_key=$(openssl rand -hex 32)
secret_id=$(openssl rand -hex 32)
compose() {
    docker compose -p "$project" --project-directory "$directory" \
        -f "$directory/compose.yml" -f "$directory/compose.check.yml" "$@"
}
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        compose logs --no-color --tail 60 2> /dev/null || true
        docker logs --tail 30 "$server" 2> /dev/null || true
    fi
    compose down --volumes --timeout 5 > /dev/null 2>&1 || true
    docker rm -f "$server" > /dev/null 2>&1 || true
    docker network rm "$network" > /dev/null 2>&1 || true
    rm -rf "$directory" opentofu/trousseau/.terraform
    exit "$status"
}
trap cleanup EXIT

# The files deploy.yml writes, with its variables
if ! output=$(uv run ansible luxembourg -c local -e "ansible_python_interpreter=$(uv run which python)" \
    -e trousseau_api_url=http://127.0.0.1:8200 -e trousseau_seal_key_id=check \
    -e '{"trousseau_proxy_networks": ["172.16.0.0/12"]}' \
    -m ansible.builtin.template -a "src=services/trousseau/config.hcl.j2 dest=$directory/config.hcl"); then
    echo "$output"
    exit 1
fi
cp services/trousseau/compose.yml "$directory/"
mkdir -p "$directory/data"
chmod -R a+rX "$directory"
cat > "$directory/.env" <<EOF
USER_ID=$(id -u)
GROUP_ID=$(id -g)
HOST=trousseau.test
PROXY_NETWORK=$network
SEAL_KEY=$seal_key
AUTOMATION_SECRET_ID=$secret_id
EOF
# Here only: the API on the loopback, for OpenTofu
cat > "$directory/compose.check.yml" <<EOF
services:
  openbao:
    ports:
      - "127.0.0.1:8200:8200"
EOF
docker network create "$network" > /dev/null
compose up -d --wait --quiet-pull
echo "ok    the first start initializes OpenBao and its static key unseals it"

# opentofu/trousseau, as deploy.yml applies it
export TF_VAR_state_path=$directory/opentofu.tfstate
export TF_VAR_state_passphrase=check-trousseau-state-passphrase
export TF_VAR_address=http://127.0.0.1:8200
export TF_VAR_automation_secret_id=$secret_id
export TF_VAR_administrator_email=check@example.org
export TF_VAR_automation_ssh_sources='["192.168.0.0/24", "100.64.0.0/16"]'
export TF_REGISTRY_CLIENT_TIMEOUT=120
tofu -chdir=opentofu/trousseau init -input=false -reconfigure > /dev/null
tofu -chdir=opentofu/trousseau apply -input=false -auto-approve > /dev/null
set +e
tofu -chdir=opentofu/trousseau plan -input=false -detailed-exitcode > "$directory/plan.txt"
plan=$?
set -e
if [ "$plan" -ne 0 ]; then
    echo "a second plan is not empty (exit code $plan):"
    cat "$directory/plan.txt"
    exit 1
fi
echo "ok    OpenTofu configures it through the AppRole, and a second plan has nothing to change"

bao() {
    docker exec -i -e BAO_ADDR=http://127.0.0.1:8200 -e "BAO_TOKEN=${token:-}" trousseau bao "$@"
}
token=$(bao write -field=token auth/approle/login role_id=deploiement secret_id="$secret_id")

# The keys: the owner's, Ansible's and the SSH server's host key
mkdir -p "$directory/ssh"
for name in alix ansible host; do
    ssh-keygen -q -t ed25519 -N "" -C "$name" -f "$directory/ssh/$name"
done
bao write -field=signed_key ssh-utilisateurs/sign/alix public_key=- < "$directory/ssh/alix.pub" > "$directory/ssh/alix-cert.pub"
bao write -field=signed_key ssh-utilisateurs/sign/ansible public_key=- < "$directory/ssh/ansible.pub" > "$directory/ssh/ansible-cert.pub"
bao write -field=signed_key ssh-hotes/sign/hotes cert_type=host valid_principals=check.anneraud.fr \
    public_key=- < "$directory/ssh/host.pub" > "$directory/ssh/host-cert.pub"
bao read -field=public_key ssh-utilisateurs/config/ca > "$directory/ssh/user_ca.pub"
bao read -field=public_key ssh-hotes/config/ca > "$directory/ssh/host_ca.pub"

certificate=$(ssh-keygen -L -f "$directory/ssh/alix-cert.pub")
principals=$(awk '/Principals:/ { listed = 1; next } /Critical Options:/ { listed = 0 } listed { print $1 }' <<< "$certificate")
if [ "$principals" != alix_anneraud ]; then
    echo "the owner's certificate is not for alix_anneraud only:"
    echo "$certificate"
    exit 1
fi
if ! ssh-keygen -L -f "$directory/ssh/ansible-cert.pub" | grep -q "source-address 192.168.0.0/24,100.64.0.0/16"; then
    echo "Ansible's certificate is not limited to its networks:"
    ssh-keygen -L -f "$directory/ssh/ansible-cert.pub"
    exit 1
fi
echo "ok    the certificates name their account, Ansible's only from its networks"

# An SSH server that trusts the users' authority and presents its host certificate
chmod 0600 "$directory/ssh/host"
chmod a+r "$directory/ssh/"*.pub
docker run -d --name "$server" -p 127.0.0.1:2222:22 -v "$directory/ssh:/check:ro" alpine:3.22 sh -c '
    set -e
    apk add --no-cache openssh-server > /dev/null
    for user in alix_anneraud ansible; do
        adduser -D "$user"
        sed -i "s/^$user:!/$user:*/" /etc/shadow
    done
    install -m 0600 /check/host /etc/ssh/ssh_host_ed25519_key
    install -m 0644 /check/host-cert.pub /etc/ssh/ssh_host_ed25519_key-cert.pub
    install -m 0644 /check/user_ca.pub /etc/ssh/user_ca.pub
    printf "%s\n" "HostKey /etc/ssh/ssh_host_ed25519_key" \
        "HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub" \
        "TrustedUserCAKeys /etc/ssh/user_ca.pub" "PasswordAuthentication no" > /etc/ssh/sshd_config
    exec /usr/sbin/sshd -D -e' > /dev/null
printf '@cert-authority check.anneraud.fr %s\n' "$(cat "$directory/ssh/host_ca.pub")" > "$directory/ssh/known_hosts"
login() {
    # $1: key, $2: account
    ssh -p 2222 -i "$directory/ssh/$1" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$directory/ssh/known_hosts" \
        -o HostKeyAlias=check.anneraud.fr "$2@127.0.0.1" true 2>> "$directory/ssh.log"
}
for _ in $(seq 30); do
    if login alix alix_anneraud; then
        break
    fi
    sleep 2
done
if ! login alix alix_anneraud; then
    echo "the owner's certificate does not log in (the host certificate is checked too):"
    cat "$directory/ssh.log"
    exit 1
fi
if login alix ansible; then
    echo "the owner's certificate logs in as ansible"
    exit 1
fi
# Ansible's certificate only works from the LAN and the VPN, not from Docker's network
if login ansible ansible; then
    echo "Ansible's certificate logs in from outside its networks"
    exit 1
fi
mv "$directory/ssh/alix-cert.pub" "$directory/ssh/alix-cert.pub.unused"
if login alix alix_anneraud; then
    echo "a key without a certificate logs in"
    exit 1
fi
echo "ok    SSH trusts the certificates, only for their account and networks, and the host certificate"

# A restart: unsealed again by the static key, configuration kept
docker restart trousseau > /dev/null
for _ in $(seq 30); do
    if bao status > /dev/null 2>&1; then
        break
    fi
    sleep 2
done
token=$(bao write -field=token auth/approle/login role_id=deploiement secret_id="$secret_id")
if [ "$(bao read -field=public_key ssh-utilisateurs/config/ca)" != "$(cat "$directory/ssh/user_ca.pub")" ]; then
    echo "after a restart, the users' authority changed or cannot be read"
    exit 1
fi
echo "ok    a restart unseals OpenBao again, with its authorities kept"
