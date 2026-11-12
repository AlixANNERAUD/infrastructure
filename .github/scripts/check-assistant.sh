#!/usr/bin/env bash
# Lay out Hermes Agent (services/assistant) as its playbook does, start it with
# its own Compose file on a stand-in proxy network, and check that:
# - it gets healthy with only the capabilities its compose file keeps,
# - the playbook's settings (the proxy network trusted by the dashboard) are
#   applied, and applying them again changes nothing,
# - Hermes' own processes (gateway, dashboard) run as the deployment's user,
# - the dashboard on the proxy network requires the login from .env: it
#   refuses a wrong password and accepts the right one.
set -euo pipefail

directory=$(mktemp -d)
project=check-assistant
network=check-assistant-$$
user=2000
username=checkassistant
password=checkassistantpassword0123
secret=checkassistantsecret0123456789abcdef
curl_image=curlimages/curl:8.22.0
host=assistant.anneraud.fr

compose() {
    docker compose -p "$project" --project-directory "$directory" -f "$directory/compose.yml" "$@"
}
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        compose ps -a 2>&1 || true
        compose logs --tail 120 2>&1 || true
    fi
    compose down --volumes --timeout 5 > /dev/null 2>&1 || true
    docker network rm "$network" > /dev/null 2>&1 || true
    sudo rm -rf "$directory"
    exit "$status"
}
trap cleanup EXIT

docker network create "$network" > /dev/null
subnet=$(docker network inspect "$network" --format '{{ (index .IPAM.Config 0).Subnet }}')

# The service folder, as compose_service lays it out
cp services/assistant/compose.yml "$directory/"
cat > "$directory/.env" <<EOF
NAME=assistant
USER_ID=$user
GROUP_ID=$user
HOST=$host
PROXY_NETWORK=$network
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=$username
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=$password
HERMES_DASHBOARD_BASIC_AUTH_SECRET=$secret
EOF
mkdir "$directory/data"
sudo chown "$user:$user" "$directory/data"
sudo chmod 0700 "$directory/data"

wait_healthy() {
    for _ in $(seq 1 100); do
        health=$(docker inspect assistant --format '{{ .State.Health.Status }}' 2> /dev/null || true)
        [ "$health" = healthy ] && return 0
        sleep 3
    done
    echo "error Hermes is not healthy ($health)"
    exit 1
}

compose up -d
wait_healthy
echo "ok    Hermes is healthy with its reduced capabilities"

# As the playbook's post_tasks
current=$(docker exec assistant hermes config get dashboard.trusted_proxies)
if grep -qF -- "$subnet" <<< "$current"; then
    echo "error the proxy network is trusted before the playbook sets it: $current"
    exit 1
fi
docker exec assistant hermes config set dashboard.trusted_proxies "[\"$subnet\"]" > /dev/null
compose restart
wait_healthy
current=$(docker exec assistant hermes config get dashboard.trusted_proxies)
if ! grep -qF -- "$subnet" <<< "$current"; then
    echo "error the proxy network is not trusted after the playbook sets it: $current"
    exit 1
fi
echo "ok    the dashboard trusts the proxy network once set, and the playbook sees it ($current)"

# Hermes' own processes (the gateway, the dashboard: its Python) run as the
# deployment's user; only s6's supervision tree and init scripts run as root
processes=$(docker top assistant -eo pid,uid,args)
hermes_processes=$(grep -E '/opt/hermes/\.venv/bin/python' <<< "$processes" || true)
if [ "$(grep -cE "^ *[0-9]+ +$user " <<< "$hermes_processes")" -lt 2 ] \
    || grep -vE "^ *[0-9]+ +$user " <<< "$hermes_processes" | grep -q .; then
    echo "error Hermes' processes do not all run as $user:"
    echo "$processes"
    exit 1
fi
echo "ok    the gateway and the dashboard run as $user"

curl_proxy() {
    docker run --rm --network "$network" "$curl_image" -sS --max-time 10 -H "Host: $host" "$@"
}
status=$(curl_proxy http://assistant:9119/api/status)
if ! grep -q '"basic"' <<< "$status"; then
    echo "error the dashboard does not require its login: $status"
    exit 1
fi
code=$(curl_proxy -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    --data "{\"provider\": \"basic\", \"username\": \"$username\", \"password\": \"wrong-password\"}" \
    http://assistant:9119/auth/password-login)
if [ "$code" != 401 ]; then
    echo "error the dashboard answers $code to a wrong password"
    exit 1
fi
code=$(curl_proxy -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    --data "{\"provider\": \"basic\", \"username\": \"$username\", \"password\": \"$password\"}" \
    http://assistant:9119/auth/password-login)
if [ "$code" != 200 ]; then
    echo "error the dashboard answers $code to the right password"
    exit 1
fi
echo "ok    the dashboard requires its login on the proxy network"
