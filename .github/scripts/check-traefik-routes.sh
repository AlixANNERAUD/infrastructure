#!/usr/bin/env bash
# Load Bruxelles' routes in a real Traefik, with both of its providers as
# deployed: the file routes rendered from inventory/host_vars/bruxelles/traefik.yml
# (TrueNAS Apps and LAN devices) with the shared policy, and the Docker labels
# of the stacks deployed on Bruxelles, carried by stand-in containers (whoami)
# on a network named like Bruxelles' proxy network. Every router must be
# enabled and match the routing expected below, and requests check the
# backends, the internal allowlist and the login rate limits.
set -euo pipefail

directory=$(mktemp -d)
project=check-traefik-routes-$$
container=$project
# The stacks' labels and Compose files name Bruxelles' proxy network
proxy_network=$(sed -n 's/^proxy_network: *//p' inventory/host_vars/bruxelles/main.yml)
# Answers every path with its hostname, on the port the labels give
stand_in_image=traefik/whoami:v1.12.0
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        docker logs --tail 80 "$container" 2>&1 || true
    fi
    docker rm -f "$container" > /dev/null 2>&1 || true
    docker compose -p "$project" -f "$directory/stand-ins.json" down --timeout 1 > /dev/null 2>&1 || true
    docker network rm "$proxy_network" > /dev/null 2>&1 || true
    rm -rf "$directory"
    exit "$status"
}
trap cleanup EXIT

mkdir -p "$directory/dynamic"
if ! output=$(uv run ansible bruxelles -c local -e "ansible_python_interpreter=$(uv run which python)" \
    -m ansible.builtin.template -a "src=services/proxy/routes.yml.j2 dest=$directory/dynamic/routes.yml"); then
    echo "$output"
    exit 1
fi
cp services/proxy/policy.yml "$directory/dynamic/policy.yml"
# The default certificate is refused (sniStrict) and the ACME server is
# unreachable on purpose, so the tested names get a self-signed certificate
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=check.test \
    -addext "subjectAltName=DNS:anneraud.fr,DNS:*.anneraud.fr,DNS:*.bruxelles.anneraud.fr,DNS:*.dera.page,DNS:*.xila.dev" \
    -keyout "$directory/dynamic/check.key" -out "$directory/dynamic/check.crt" 2> /dev/null
cat > "$directory/dynamic/check.yml" <<'EOF'
tls:
  certificates:
    - certFile: /dynamic/check.crt
      keyFile: /dynamic/check.key
EOF
chmod -R a+rX "$directory"

# Stand-ins of the labelled containers of every stack deployed on Bruxelles,
# with the labels docker compose config gives them (the .env holds
# placeholders, except the values deploy.yml takes from the host's variables)
uv run python - "$directory" "$proxy_network" "$stand_in_image" <<'EOF'
import json
import re
import subprocess
import sys
from pathlib import Path

import jinja2
import yaml

directory, proxy_network, image = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
host_variables = {}
for file in sorted(Path("inventory/host_vars/bruxelles").glob("*.yml")):
    host_variables.update(yaml.safe_load(file.read_text()))
groups = yaml.safe_load(Path("inventory/hosts.yml").read_text())["all"]["children"]["services"]["children"]
# Traefik itself is replaced by the checked instance
stacks = sorted(
    name for name, group in groups.items()
    if "bruxelles" in (group or {}).get("hosts", {}) and name != "proxy" and Path(f"services/{name}/compose.yml").exists()
)


def placeholder(name):
    """Same placeholders as check-compose.sh."""
    if name.endswith("PORT") or name.endswith("_ID"):
        return "1000"
    if name.endswith("PATH"):
        return "/placeholder"
    return "placeholder"


def deployed_environment(stack):
    """Variables deploy.yml writes to .env from the host's variables alone: values that need the vault,
    other hosts or Ansible's own filters keep their placeholder."""
    environment = {}
    for play in yaml.safe_load(Path(f"services/{stack}/deploy.yml").read_text()):
        for role in play.get("roles", []):
            if isinstance(role, dict) and role.get("role") == "compose_service":
                for name, value in role.get("vars", {}).get("compose_service_environment", {}).items():
                    if isinstance(value, str) and "{{" in value:
                        try:
                            template = jinja2.Environment(undefined=jinja2.StrictUndefined).from_string(value)
                            environment[name] = template.render(**host_variables)
                        except jinja2.TemplateError:
                            pass
    return environment


services = {}
routers = set()
for stack in stacks:
    compose = Path(f"services/{stack}/compose.yml")
    names = sorted(set(re.findall(r"\$\{([A-Za-z_][A-Za-z0-9_]*)", compose.read_text())))
    environment = {name: placeholder(name) for name in names} | deployed_environment(stack)
    # Deployed, each stack has a proxy network of its own; here they all share the stand-in one
    environment |= {name: proxy_network for name, value in environment.items()
                    if name == "PROXY_NETWORK" or str(value).startswith("proxy-")}
    environment_file = directory / f"{stack}.env"
    environment_file.write_text("".join(f"{name}={value}\n" for name, value in environment.items()))
    configuration = json.loads(subprocess.run(
        ["docker", "compose", "--env-file", str(environment_file), "-f", str(compose), "config", "--format", "json"],
        check=True, capture_output=True, text=True,
    ).stdout)
    for name, service in configuration["services"].items():
        labels = service.get("labels", {})
        if labels.get("traefik.enable") != "true":
            continue
        ports = {value for key, value in labels.items() if re.fullmatch(r"traefik\.http\.services\.[^.]+\.loadbalancer\.server\.port", key)}
        if len(ports) != 1:
            sys.exit(f"{stack}/{name} serves on ports {sorted(ports)}: a stand-in serves one")
        routers |= {match.group(1) for key in labels if (match := re.match(r"traefik\.http\.routers\.([^.]+)\.", key))}
        stand_in = f"{stack}-{name}"
        # A second network, as the stacks' internal one: Traefik must pick the proxy network
        networks = ["proxy"] + (["other"] if len(service.get("networks", {})) > 1 else [])
        services[stand_in] = {
            "image": image,
            "hostname": stand_in,
            "command": ["--port", ports.pop()],
            "labels": labels,
            "networks": networks,
        }

(directory / "stand-ins.json").write_text(json.dumps({
    "services": services,
    "networks": {"proxy": {"name": proxy_network, "external": True}, "other": {"internal": True}},
}, indent=2))
(directory / "docker-routers").write_text(str(len(routers)))
print(f"{len(services)} stand-ins of {', '.join(stacks)}, with {len(routers)} routers")
EOF

docker network create "$proxy_network" > /dev/null
docker compose -p "$project" -f "$directory/stand-ins.json" up -d --quiet-pull

# Same image as the deployed Traefik, so Dependabot bumps both at once
image=$(sed -n 's/^ *image: "\{0,1\}\(traefik:[^"]*\)"\{0,1\}$/\1/p' services/proxy/compose.yml)

docker run -d --name "$container" --network "$proxy_network" -p 127.0.0.1::8080 -p 127.0.0.1::8443 \
    -v /var/run/docker.sock:/var/run/docker.sock:ro -v "$directory/dynamic:/dynamic:ro" "$image" \
    --api.insecure=true \
    --providers.docker=true \
    --providers.docker.exposedbydefault=false \
    --providers.docker.network="$proxy_network" \
    --providers.file.directory=/dynamic \
    --certificatesresolvers.letsencrypt.acme.storage=/tmp/acme.json \
    --certificatesresolvers.letsencrypt.acme.caServer=https://127.0.0.1:1/directory \
    --certificatesresolvers.letsencrypt.acme.tlsChallenge=true \
    --entryPoints.web-secure.address=:8443 \
    --entryPoints.web-secure.http.tls=true > /dev/null
api="http://$(docker port "$container" 8080/tcp | head -n 1)/api"
address=$(docker port "$container" 8443/tcp | head -n 1)

# Until both providers have loaded every router
docker_routers=$(cat "$directory/docker-routers")
for _ in $(seq 60); do
    if routers=$(curl -fs "$api/http/routers?per_page=1000") \
        && [ "$(echo "$routers" | grep -o '"provider":"docker"' | wc -l)" -ge "$docker_routers" ] \
        && echo "$routers" | grep -q '"provider":"file"'; then
        break
    fi
    sleep 1
done
sleep 2
curl -fs "$api/http/routers?per_page=1000" > "$directory/routers.json"
curl -fs "$api/http/middlewares?per_page=1000" > "$directory/middlewares.json"
curl -fs "$api/http/services?per_page=1000" > "$directory/services.json"
docker network inspect "$proxy_network" > "$directory/network.json"

uv run python - "$directory" "$address" <<'EOF'
import ipaddress
import json
from concurrent.futures import ThreadPoolExecutor
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

import yaml

directory, address = Path(sys.argv[1]), sys.argv[2]
port = address.rsplit(":", 1)[1]
data = yaml.safe_load(Path("inventory/host_vars/bruxelles/traefik.yml").read_text())
routes = data["traefik_routes"]
redirects = data["traefik_redirects"]
tiers = {"login": data["traefik_login_rate_limit"], "busy login": data["traefik_busy_login_rate_limit"]}


def load(name):
    return {entry["name"]: entry for entry in json.loads((directory / f"{name}.json").read_text()) if entry["provider"] in ("file", "docker")}


routers, middlewares, services = load("routers"), load("middlewares"), load("services")
file_routers = {name for name, router in routers.items() if router["provider"] == "file"}
docker_routers = {name for name, router in routers.items() if router["provider"] == "docker"}
proxy_subnets = [ipaddress.ip_network(entry["Subnet"]) for entry in json.loads((directory / "network.json").read_text())[0]["IPAM"]["Config"]]
failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def router(name):
    return routers.get(name, {})


for name, entry in sorted(routers.items()):
    check(entry["status"] == "enabled", f"router {name} is {entry['status']}: {entry.get('error')}")
    check(entry.get("entryPoints") == ["web-secure"], f"router {name} has the entrypoints {entry.get('entryPoints')}")
    check("tls" in entry, f"router {name} has no TLS")
    # The default priority, the rule's length, so that longer rules (paths, logins) win
    check(entry.get("priority", 0) in (0, len(entry.get("rule", ""))), f"router {name} has the priority {entry.get('priority')}")


def seconds(duration):
    """Seconds of a Go duration ("1m", "1m0s") or of nanoseconds, as the API may return either."""
    if isinstance(duration, (int, float)):
        return duration / 1e9
    units = {"h": 3600, "m": 60, "s": 1, "ms": 1e-3}
    return sum(float(value) * units[unit] for value, unit in re.findall(r"([0-9.]+)(ms|h|m|s)", str(duration)))


# Routes moved from the file provider to the labels of their stacks: same names, rules (so priorities),
# entrypoints, restrictions, certificate requests and backends as their former file routes
internal = ["internal-allowlist@file"]
expected = {
    "docmost": {"stand_in": "notes-docmost", "rule": "Host(`notes.anneraud.fr`)", "url": "http:3000"},
    "qbittorrent": {"stand_in": "telechargement-gluetun", "rule": "Host(`telechargement.anneraud.fr`)", "middlewares": internal, "url": "http:30096"},
    "wakapi": {
        "stand_in": "wakapi-wakapi", "rule": "Host(`wakapi.anneraud.fr`) || Host(`wakapi.dera.page`)", "url": "http:3000", "zone": "dera.page",
    },
    "zitadel": {"stand_in": "authentification-zitadel", "rule": "Host(`authentification.anneraud.fr`)", "url": "h2c:8080"},
    "zitadel-login": {
        "stand_in": "authentification-zitadel", "service": "zitadel", "tier": "login",
        "rule": "(Host(`authentification.anneraud.fr`)) && Method(`POST`) && (PathRegexp(`(?i)^/ui/login`))",
    },
    "zitadel-1": {
        "stand_in": "authentification-login", "rule": "(Host(`authentification.anneraud.fr`)) && PathPrefix(`/ui/v2/login`)", "url": "http:3000",
    },
    "zitadel-1-login": {
        "stand_in": "authentification-login", "service": "zitadel-1", "tier": "busy login",
        "rule": "((Host(`authentification.anneraud.fr`)) && PathPrefix(`/ui/v2/login`)) && Method(`POST`) && (PathRegexp(`(?i)^/ui/v2/login`))",
    },
    "synapse": {"stand_in": "matrix_anneraud-synapse", "rule": "Host(`matrix.anneraud.fr`)", "url": "http:8008"},
    # Synapse's admin API stays internal while the rest of matrix.anneraud.fr is public
    "synapse-1": {
        "stand_in": "matrix_anneraud-synapse", "rule": "(Host(`matrix.anneraud.fr`)) && PathPrefix(`/_synapse/admin`)",
        "middlewares": internal, "url": "http:8008",
    },
    # Only these paths of anneraud.fr: the rest of the host keeps its redirect (redirect-anneraud@file)
    "matrix-delegation": {
        "stand_in": "matrix_anneraud-synapse", "rule": "(Host(`anneraud.fr`)) && PathPrefix(`/.well-known/matrix`)", "url": "http:8008",
    },
    "matrix-delegation-1": {"stand_in": "matrix_anneraud-synapse", "rule": "(Host(`anneraud.fr`)) && PathPrefix(`/_matrix`)", "url": "http:8008"},
    "mcphub": {"stand_in": "mcphub-mcphub", "rule": "Host(`mcphub.anneraud.fr`)", "middlewares": internal, "url": "http:3000"},
    "semaphore": {"stand_in": "deploiement-semaphore", "rule": "Host(`deploiement.anneraud.fr`)", "middlewares": internal, "url": "http:3000"},
    "openbao": {
        "stand_in": "secrets_xila-openbao", "rule": "Host(`vault.xila.dev`)", "middlewares": internal,
        "url": "https:8200", "transport": "insecure-backend@file", "zone": "xila.dev",
    },
    # Exporters scraped by Vigie over Netbird: only their metrics, behind the allowlist
    "metriques-node": {
        "stand_in": "metriques-node-exporter", "rule": "Host(`metriques.bruxelles.anneraud.fr`) && PathPrefix(`/node`)",
        "middlewares": internal + ["metriques-node-path@docker"], "url": "http:9100",
    },
    "metriques-containers": {
        "stand_in": "metriques-cadvisor", "rule": "Host(`metriques.bruxelles.anneraud.fr`) && PathPrefix(`/containers`)",
        "middlewares": internal + ["metriques-containers-path@docker"], "url": "http:8080",
    },
}
check({f"{name}@docker" for name in expected} <= docker_routers, f"routers missing: {sorted({f'{name}@docker' for name in expected} - docker_routers)}")
for name, expectation in expected.items():
    entry, service_name = router(f"{name}@docker"), expectation.get("service", name)
    middleware_names = expectation.get("middlewares", []) + ([f"{name}-rate-limit@docker"] if "tier" in expectation else [])
    check(entry.get("rule") == expectation["rule"], f"router {name}@docker has the rule {entry.get('rule')}")
    check(entry.get("service", "").split("@")[0] == service_name, f"router {name}@docker goes to {entry.get('service')}")
    check(entry.get("middlewares", []) == middleware_names, f"router {name}@docker middlewares are {entry.get('middlewares')}")
    zone = expectation.get("zone")
    tls = {"certResolver": "letsencrypt", "domains": [{"main": zone, "sans": [f"*.{zone}"]}]} if zone else {}
    # The Docker provider names the default TLS options, which the file routes use implicitly
    check({key: value for key, value in entry.get("tls", {}).items() if (key, value) != ("options", "default")} == tls,
          f"router {name}@docker TLS is {entry.get('tls')}")
    if "url" in expectation:
        service = services.get(f"{service_name}@docker", {})
        servers = service.get("loadBalancer", {}).get("servers", [])
        check(len(servers) == 1, f"service {service_name}@docker has the servers {servers}")
        for server in servers:
            url = urlsplit(server.get("url", ""))
            check(f"{url.scheme}:{url.port}" == expectation["url"], f"service {service_name}@docker goes to {url.geturl()}")
            check(any(ipaddress.ip_address(url.hostname) in subnet for subnet in proxy_subnets),
                  f"service {service_name}@docker is not reached through the proxy network: {url.hostname}")
        check(service.get("loadBalancer", {}).get("serversTransport") == expectation.get("transport"),
              f"service {service_name}@docker servers transport is {service.get('loadBalancer', {}).get('serversTransport')}")
    if "tier" in expectation:
        limit = middlewares.get(f"{name}-rate-limit@docker", {}).get("rateLimit", {})
        tier = tiers[expectation["tier"]]
        check(
            (limit.get("average"), seconds(limit.get("period")), limit.get("burst")) == (tier["average"], seconds(tier["period"]), tier["burst"]),
            f"middleware {name}-rate-limit@docker is {limit}, not the {expectation['tier']} limit",
        )

# Login routers, file or labels: they only add a rate limit to their owner's router (same service and
# restrictions), for POST to the login prefixes only, with a longer rule so that it takes precedence
logins = [name for name in routers if name.split("@")[0].endswith("-login")]
check(
    {name.split("@")[0] for name in logins}
    >= {"zitadel-login", "zitadel-1-login", "vaultwarden-login", "nextcloud-login", "jellyfin-login", "home-assistant-login"},
    f"login routers are {sorted(logins)}",
)
for name in logins:
    base, provider = name.split("@")
    owner = router(f"{base.removesuffix('-login')}@{provider}")
    entry = router(name)
    check(bool(owner), f"router {name} has no owner router")
    check("internal-allowlist@file" not in owner.get("middlewares", []), f"router {name} rate limits an internal route")
    check(entry.get("service") == owner.get("service"), f"router {name} has another service than its owner")
    check(entry.get("middlewares", []) == owner.get("middlewares", []) + [f"{base}-rate-limit@{provider}"],
          f"router {name} middlewares are {entry.get('middlewares')}")
    check(entry.get("rule", "").startswith(f"({owner.get('rule')}) && Method(`POST`) && ("), f"router {name} has the wrong rule {entry.get('rule')}")
    limit = middlewares.get(f"{base}-rate-limit@{provider}", {}).get("rateLimit", {})
    check(limit.get("sourceCriterion", {}).get("ipStrategy", {}).get("ipv6Subnet") == 64, f"middleware {base}-rate-limit@{provider} has no /64")

# File routes: one router per route, path and redirect, plus their login routers
file_logins = [route for route in routes if "rate_limit" in route]
count = len(routes) + sum(len(route.get("paths", [])) for route in routes) + len(redirects) + len(file_logins)
check(len(file_routers) == count, f"{len(file_routers)} file routers instead of {count}")
check(
    router("umami@file").get("rule") == "Host(`s.anneraud.fr`) || Host(`s.guenola-sahut.fr`)",
    "router umami@file has the wrong rule",
)
for route in routes:
    # A redirecting path keeps its route's allowlist
    names = [route["name"]] + [f"{route['name']}-{index}" for index in range(1, len(route.get("paths", [])) + 1)]
    for name in names:
        allowlisted = "internal-allowlist@file" in router(f"{name}@file").get("middlewares", [])
        check(allowlisted == route["internal"], f"router {name}@file internal allowlist is {allowlisted}")
    for prefix in route.get("rate_limit", {}).get("prefixes", []):
        check(f"PathRegexp(`(?i)^{re.escape(prefix)}`)" in router(f"{route['name']}-login@file").get("rule", ""),
              f"router {route['name']}-login@file does not limit {prefix}")
        # A route's login router must not catch requests meant for one of its paths
        for path in route.get("paths", []):
            check(
                not (path["prefix"].lower().startswith(prefix.lower()) or prefix.lower().startswith(path["prefix"].lower())),
                f"route {route['name']} limits {prefix}, which overlaps its path {path['prefix']}",
            )
    if "rate_limit" in route:
        limit = middlewares.get(f"{route['name']}-login-rate-limit@file", {}).get("rateLimit", {})
        check(
            (limit.get("average"), seconds(limit.get("period")), limit.get("burst"))
            == (route["rate_limit"]["average"], seconds(route["rate_limit"]["period"]), route["rate_limit"]["burst"]),
            f"middleware {route['name']}-login-rate-limit@file is {limit}",
        )


def replacement(name):
    return middlewares.get(name, {}).get("redirectRegex", {}).get("replacement", "")


check(replacement("redirect-arnaud@file").endswith("${1}"), "middleware redirect-arnaud does not keep the path")
check(replacement("redirect-anneraud@file") and not replacement("redirect-anneraud@file").endswith("${1}"),
      "middleware redirect-anneraud keeps the path")


def certificate(domain):
    return {"main": domain, "sans": [f"*.{domain}"]}


def zone(host):
    labels = host.split(".")
    return host if len(labels) == 2 else ".".join(labels[1:])


# Every zone's wildcard is requested by exactly one router, file or labels: concurrent orders for the same zone
# break each other
hosts = {host for entry in routers.values() for host in re.findall(r"Host\(`([^`]+)`\)", entry.get("rule", ""))}
requesters = {}
for name, entry in routers.items():
    tls = entry.get("tls", {})
    check(bool(tls.get("domains")) == bool(tls.get("certResolver")), f"router {name} has a resolver without domains or the reverse")
    for request in tls.get("domains", []):
        check(request == certificate(request["main"]), f"router {name} requests {request}")
        requesters.setdefault(request["main"], []).append(name)
check(set(requesters) == {zone(host) for host in hosts}, f"requested zones {sorted(requesters)}")
for requested_zone, names in requesters.items():
    check(len(names) == 1, f"zone {requested_zone} requested by {names}")
check(requesters.get("bruxelles.anneraud.fr") == ["portainer@file"], "bruxelles.anneraud.fr is not requested by portainer@file")
check(requesters.get("guenola-sahut.fr") == ["umami@file"], "guenola-sahut.fr is not requested by umami@file")

# Sites proxied by Cloudflare must refuse connections that skip it, and nothing else may
cloudflare_networks = yaml.safe_load(Path("inventory/group_vars/all.yml").read_text())["cloudflare_networks"]
cloudflare_routers = {"odoo-minitrainstore@file", "odoo-guenola-sahut@file", "redirect-minitrainstore@file", "redirect-guenola-sahut@file"}
expected_cloudflare = {f"{route['name']}@file" for route in routes if route.get("cloudflare_only")} | {
    f"redirect-{redirect['name']}@file" for redirect in redirects if redirect.get("cloudflare_only")
}
check(expected_cloudflare == cloudflare_routers, f"cloudflare_only is set on {sorted(expected_cloudflare)}")
check(cloudflare_routers <= set(routers), f"routers missing: {sorted(cloudflare_routers - set(routers))}")
for name, entry in sorted(routers.items()):
    chain = entry.get("middlewares", [])
    check(("cloudflare-only@file" in chain) == (name in cloudflare_routers), f"router {name} Cloudflare restriction is wrong")
    # A redirect replies on its own, so every restriction must run before it
    redirecting = [position for position, middleware in enumerate(chain) if middleware.startswith("redirect-") or "-redirect@" in middleware]
    for restriction in ("cloudflare-only@file", "internal-allowlist@file"):
        if restriction in chain and redirecting:
            check(chain.index(restriction) < min(redirecting), f"router {name} runs {restriction} after a redirect")
check(
    middlewares.get("cloudflare-only@file", {}).get("ipAllowList", {}).get("sourceRange") == cloudflare_networks,
    "middleware cloudflare-only does not allow exactly cloudflare_networks",
)


# Requests from this machine, which is outside the internal allowlist (through Docker's port forwarding)
def request(host, path, method="GET"):
    result = subprocess.run(
        ["curl", "-sk", "--max-time", "10", "-X", method, "--resolve", f"{host}:{port}:127.0.0.1", "-w", "\n%{http_code}", f"https://{host}:{port}{path}"],
        capture_output=True, text=True,
    )
    body, _, status = result.stdout.rpartition("\n")
    return int(status or 0), body


for name, expectation in expected.items():
    if "tier" in expectation:
        continue
    rule = expectation["rule"]
    host = re.search(r"Host\(`([^`]+)`\)", rule).group(1)
    prefix = re.search(r"PathPrefix\(`([^`]+)`\)", rule)
    path = (prefix.group(1) if prefix else "") + "/check"
    status, body = request(host, path)
    if internal[0] in expectation.get("middlewares", []):
        check(status == 403, f"https://{host}{path} answers {status} outside the allowlist")
    elif expectation["url"].startswith("http:"):
        check(status == 200 and f"Hostname: {expectation['stand_in']}" in body, f"https://{host}{path} answers {status} from {body[:40]!r}")
    else:
        # Traefik routed it (no 404), to a stand-in that does not speak the backend's protocol
        check(status not in (403, 404, 429), f"https://{host}{path} answers {status}")
status, _ = request("anneraud.fr", "/check")
check(status == 301, f"https://anneraud.fr/check answers {status} instead of the redirect to www")


# Login POSTs (any case) are refused with 429 once the client's burst is spent, and only them. The burst and
# a few more are sent at once, so that no token comes back meanwhile, however slow the backend
def spend(host, paths, burst):
    with ThreadPoolExecutor(burst + 3) as executor:
        statuses = list(executor.map(lambda attempt: request(host, paths[attempt % len(paths)], "POST")[0], range(burst + 3)))
    check(statuses.count(429) == 3, f"https://{host}{paths[0]} answered {sorted(statuses)} to {burst + 3} logins, with a burst of {burst}")


host = "authentification.anneraud.fr"
spend(host, ["/ui/login/password", "/UI/Login/password"], tiers["login"]["burst"])
check(request(host, "/ui/login/password")[0] != 429, "the former login page refuses GET once logins are limited")
# Its own bucket: the former login pages' spent burst does not count. Its path prefix is case-sensitive,
# as Zitadel's login serves it
spend(host, ["/ui/v2/login/password", "/ui/v2/login/PASSWORD"], tiers["busy login"]["burst"])
check(request(host, "/ui/v2/login/password")[0] == 200, "the login refuses GET once logins are limited")
check(request(host, "/check", "POST")[0] != 429, "POST outside the login pages is limited")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(f"{len(file_routers)} file and {len(docker_routers)} label routers enabled and as expected")
EOF
