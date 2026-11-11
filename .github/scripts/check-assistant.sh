#!/usr/bin/env bash
# Lay out OpenClaw (services/assistant) as its playbook does, with gateway.json
# rendered from its template for a stand-in proxy network, start it with its
# own Compose file, and check that:
# - the configuration container writes the deployment's gateway settings,
# - the gateway starts with them on its read-only root, as the deployment's
#   user, and answers /healthz on the proxy network,
# - its gateway answers the token from .env and refuses another one.
set -euo pipefail

directory=$(mktemp -d)
project=check-assistant
network=check-assistant-$$
user=2000
token=checkassistantgatewaytoken0123456789
curl_image=curlimages/curl:8.22.0
host=assistant.anneraud.fr

compose() {
    docker compose -p "$project" --project-directory "$directory" -f "$directory/compose.yml" "$@"
}
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        compose ps -a 2>&1 || true
        compose logs --tail 80 2>&1 || true
    fi
    compose down --volumes --timeout 1 > /dev/null 2>&1 || true
    docker network rm "$network" > /dev/null 2>&1 || true
    sudo rm -rf "$directory"
    exit "$status"
}
trap cleanup EXIT

docker network create "$network" > /dev/null
subnet=$(docker network inspect "$network" --format '{{ (index .IPAM.Config 0).Subnet }}')

# The service folder, as compose_service lays it out
cp services/assistant/compose.yml "$directory/"
uv run ansible localhost --connection local -m ansible.builtin.template \
    -a "src=services/assistant/gateway.json.j2 dest=$directory/gateway.json mode=0644" \
    -e "assistant_host=$host" -e "{\"assistant_trusted_proxies\": [\"$subnet\"]}" > /dev/null
cat > "$directory/.env" <<EOF
USER_ID=$user
GROUP_ID=$user
HOST=$host
PROXY_NETWORK=$network
OPENCLAW_GATEWAY_TOKEN=$token
EOF
mkdir "$directory/home"
sudo chown "$user:$user" "$directory/home"
sudo chmod 0700 "$directory/home"

# Not --wait: it would count the configuration container, which exits once done
compose up -d
for _ in $(seq 1 100); do
    health=$(docker inspect assistant --format '{{ .State.Health.Status }}' 2> /dev/null || true)
    [ "$health" = healthy ] && break
    sleep 3
done
if [ "$health" != healthy ]; then
    echo "error the gateway is not healthy ($health)"
    exit 1
fi
echo "ok    the gateway is healthy after its configuration"

configuration=$(docker exec assistant cat /home/node/.openclaw/openclaw.json)
for expected in "https://$host" "$subnet" '"token"' '"lan"'; do
    if ! grep -qF -- "$expected" <<< "$configuration"; then
        echo "error the configuration lacks $expected:"
        echo "$configuration"
        exit 1
    fi
done
echo "ok    the configuration holds the deployment's gateway settings"

if [ "$(docker exec assistant id -u)" != "$user" ]; then
    echo "error the gateway does not run as $user"
    exit 1
fi
if docker exec assistant touch /app/check 2> /dev/null; then
    echo "error the gateway's root is writable"
    exit 1
fi
echo "ok    the gateway runs as $user on a read-only root"

docker run --rm --network "$network" "$curl_image" -fsS --max-time 10 http://assistant:18789/healthz > /dev/null
echo "ok    the gateway answers /healthz on the proxy network"

docker exec assistant node dist/index.js gateway health --token "$token" > /dev/null
if docker exec assistant node dist/index.js gateway health --token wrong-token > /dev/null 2>&1; then
    echo "error the gateway accepts a wrong token"
    exit 1
fi
echo "ok    the gateway answers its token and refuses another one"
