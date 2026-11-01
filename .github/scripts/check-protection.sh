#!/usr/bin/env bash
# Lay out CrowdSec (services/protection) and Traefik (services/proxy) as their
# playbooks do on a host of the protection group, start both with their own
# Compose files, and check that:
# - the allowlist holds the internal-allowlist networks and refuses decisions on them,
# - a banned address gets 403 from Traefik while others get through,
# - the LAN and the VPN get through even when banned (the bouncer trusts them),
# - an unban lets the address back in,
# - CrowdSec reads Traefik's access log and bans a scanning address by itself.
# Test clients are told apart with X-Forwarded-For, which this Traefik trusts
# from the Docker networks the way the deployed one trusts it from Cloudflare.
set -euo pipefail

directory=$(mktemp -d)
proxy=$directory/proxy
protection=$directory/protection
proxy_network=check-protection-proxy-$$
key=checkprotectionbouncerkey0123456789
# Addresses the requests to Traefik come from, through Docker's port forwarding
docker_networks='["172.16.0.0/12", "10.0.0.0/8", "127.0.0.0/8"]'
banned=203.0.113.10
allowed=203.0.113.20
scanner=203.0.113.30
lan=192.168.0.50

compose_proxy() {
    docker compose -p check-protection-proxy --project-directory "$proxy" \
        -f "$proxy/compose.yml" -f "$proxy/compose.check.yml" "$@"
}
compose_protection() {
    docker compose -p check-protection --project-directory "$protection" \
        -f "$protection/compose.yml" -f "$protection/compose.check.yml" "$@"
}
cscli() {
    docker exec crowdsec cscli "$@"
}
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        compose_protection logs --no-color --tail 80 || true
        compose_proxy logs --no-color --tail 80 || true
    fi
    compose_proxy down --volumes --timeout 5 > /dev/null 2>&1 || true
    compose_protection down --volumes --timeout 5 > /dev/null 2>&1 || true
    docker network rm "$proxy_network" protection > /dev/null 2>&1 || true
    # CrowdSec's files belong to root
    sudo -n rm -rf "$directory" 2> /dev/null || rm -rf "$directory"
    exit "$status"
}
trap cleanup EXIT

render() {
    # $1: host, $2: template, $3: destination, then extra variables
    local host=$1 source=$2 destination=$3
    shift 3
    if ! output=$(uv run ansible "$host" -c local -e "ansible_python_interpreter=$(uv run which python)" "$@" \
        -m ansible.builtin.template -a "src=$source dest=$destination"); then
        echo "$output"
        exit 1
    fi
}

# Same networks as deployed: internal-allowlist's, read by the inventory
internal_networks=$(uv run ansible luxembourg -c local -e "ansible_python_interpreter=$(uv run which python)" \
    -m ansible.builtin.debug -a "msg={{ internal_networks | join(' ') }}" | sed -n 's/^ *"msg": "\(.*\)"$/\1/p')
if [ -z "$internal_networks" ]; then
    echo "internal_networks is empty"
    exit 1
fi

# CrowdSec, with the files deploy.yml copies
mkdir -p "$protection/config" "$protection/data"
cp services/protection/compose.yml "$protection/compose.yml"
uv run python - "$protection" <<'EOF'
import shutil
import sys
from pathlib import Path

import yaml

play = yaml.safe_load(Path("services/protection/deploy.yml").read_text())[0]
role = next(role for role in play["roles"] if role["role"] == "compose_service")["vars"]
for entry in role.get("compose_service_files", []):
    destination = Path(sys.argv[1]) / entry["destination"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(Path("services/protection") / entry["source"], destination)
EOF
echo "BOUNCER_KEY=$key" > "$protection/.env"
# Test alerts must not reach the community blocklist
cat > "$protection/compose.check.yml" <<'EOF2'
services:
  crowdsec:
    environment:
      DISABLE_ONLINE_API: "true"
EOF2

# Traefik, with the files deploy.yml writes on a host of the protection group
mkdir -p "$proxy/dynamic" "$proxy/protection" "$proxy/letsencrypt"
cp services/proxy/compose.yml "$proxy/compose.yml"
cp services/proxy/policy.yml "$proxy/dynamic/policy.yml"
render luxembourg services/proxy/protection.yml.j2 "$proxy/dynamic/protection.yml" -e "{\"cloudflare_networks\": $docker_networks}"
printf '%s' "$key" > "$proxy/protection/bouncer_key"
# The default certificate is refused (sniStrict), so the test name gets its own
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=check.test -addext subjectAltName=DNS:check.test \
    -keyout "$proxy/dynamic/check.key" -out "$proxy/dynamic/check.crt" 2> /dev/null
# check.test goes to a backend on the metrics entrypoint (Traefik's API, which
# answers /api/version and 404 elsewhere): requests to internal services are
# not in the access log, requests to this backend are
cat > "$proxy/dynamic/check.yml" <<'EOF'
tls:
  certificates:
    - certFile: /etc/traefik/dynamic/check.crt
      keyFile: /etc/traefik/dynamic/check.key
http:
  routers:
    check:
      rule: Host(`check.test`)
      entryPoints: [web-secure]
      service: check
      tls: {}
    check-backend:
      rule: PathPrefix(`/`)
      entryPoints: [metrics]
      service: api@internal
  services:
    check:
      loadBalancer:
        servers:
          - url: http://127.0.0.1:8082
EOF
cat > "$proxy/.env" <<EOF
CLOUDFLARE_EMAIL=check@example.org
CLOUDFLARE_API_KEY=check
PROXY_NETWORK=$proxy_network
TRAEFIK_DASHBOARD_HOST=traefik.check.test
TRAEFIK_FEDERATION_PUBLISH=127.0.0.1::8448
TRAEFIK_TRUSTED_PROXIES=$(echo "$docker_networks" | tr -d '[] "')
TRAEFIK_ENTRYPOINT_MIDDLEWARES=$(sed -n "s/^ *TRAEFIK_ENTRYPOINT_MIDDLEWARES: \"{{ '\([^']*\)'.*/\1/p" services/proxy/deploy.yml)
EOF
# Without its own labels Traefik requests no certificate for its dashboard
cat > "$proxy/compose.check.yml" <<'EOF'
services:
  traefik:
    labels:
      - traefik.enable=false
EOF
chmod -R a+rX "$directory"
if ! grep -q '^TRAEFIK_ENTRYPOINT_MIDDLEWARES=crowdsec@file,' "$proxy/.env"; then
    echo "The entrypoint middlewares of a protected host do not start with crowdsec@file"
    exit 1
fi

docker network create --internal protection > /dev/null
docker network create "$proxy_network" > /dev/null

# The engine installs the hub collections before its local API answers
compose_protection up -d --wait --wait-timeout 300 --quiet-pull
compose_proxy up -d --quiet-pull

request() {
    # Status of a request to check.test from the client address $1, for path $2
    curl -ks -o /dev/null -w '%{http_code}' --max-time 10 --resolve check.test:443:127.0.0.1 \
        -H "X-Forwarded-For: $1" "https://check.test${2:-/api/version}" || true
}

wait_for() {
    # Retry the command for up to $1 seconds
    local timeout=$1
    shift
    for _ in $(seq "$timeout"); do
        if "$@"; then
            return 0
        fi
        sleep 1
    done
    return 1
}
answers() {
    # The address $1 gets the status $2
    [ "$(request "$1")" = "$2" ]
}

if ! wait_for 90 answers "$allowed" 200; then
    echo "Traefik did not answer 200 through the bouncer: $(request "$allowed")"
    exit 1
fi
echo "ok    Traefik answers through the CrowdSec bouncer"

# The allowlist, as deploy.yml applies it (twice: the second run must change nothing)
# shellcheck disable=SC2086
docker exec -i crowdsec sh -s -- internal "Networks of the internal-allowlist middleware" $internal_networks \
    < services/protection/allowlist.sh
# shellcheck disable=SC2086
second=$(docker exec -i crowdsec sh -s -- internal "Networks of the internal-allowlist middleware" $internal_networks \
    < services/protection/allowlist.sh)
if [ -n "$second" ]; then
    echo "The allowlist changed on its second run: $second"
    exit 1
fi
listed=$(cscli allowlists inspect internal -o raw | tail -n +2 | cut -d, -f3 | sort | tr '\n' ' ')
expected=$(printf '%s\n' $internal_networks | sort | tr '\n' ' ')
if [ "$listed" != "$expected" ]; then
    echo "The allowlist holds $listed instead of $expected"
    exit 1
fi
if cscli decisions add --ip "$lan" --duration 1h > /dev/null 2>&1; then
    echo "CrowdSec accepted a decision on $lan, which is allowlisted"
    exit 1
fi
echo "ok    the allowlist holds the internal networks and refuses decisions on them"

cscli decisions add --ip "$banned" --duration 1h --reason check
cscli decisions add --ip "$lan" --duration 1h --reason check --bypass-allowlist
# The bouncer fetches decisions every 15 s
if ! wait_for 60 answers "$banned" 403; then
    echo "$banned is banned but gets $(request "$banned")"
    exit 1
fi
for address in "$allowed" "$lan"; do
    status=$(request "$address")
    if [ "$status" != 200 ]; then
        echo "$address gets $status instead of 200"
        exit 1
    fi
done
echo "ok    the banned address gets 403, others and the LAN (banned too) get 200"

cscli decisions delete --ip "$banned"
if ! wait_for 60 answers "$banned" 200; then
    echo "$banned is unbanned but gets $(request "$banned")"
    exit 1
fi
echo "ok    the unbanned address gets 200 again"

# A scan: more than 10 different missing pages (crowdsecurity/http-probing)
for page in $(seq 20); do
    request "$scanner" "/check-scan-$page" > /dev/null
done
if ! wait_for 90 answers "$scanner" 403; then
    echo "CrowdSec did not ban $scanner after its scan; acquisition and alerts:"
    cscli metrics show acquisition || true
    cscli alerts list || true
    exit 1
fi
echo "ok    CrowdSec read Traefik's access log and banned a scanning address"
