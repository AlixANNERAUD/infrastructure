#!/usr/bin/env bash
# Every app reached through Traefik has a proxy network of its own, shared
# only with Traefik (docs: Réseau, isolation des applications). Check that:
# - each routed container sits on the network named ${PROXY_NETWORK}, which
#   its deploy.yml gives it (compose_service_proxy), and tells Traefik to use
#   it: on several networks, Traefik would otherwise pick one at random,
# - each routed container names its port: Traefik can't detect it on some
#   networks,
# - no stack joins the former shared networks (traefik, proxy) by name,
# - each Bruxelles route to a container names that app's proxy network.
set -euo pipefail

uv run python - <<'PYTHON'
import re
import sys
from pathlib import Path

import yaml

failures = []
# The metrics exporters are routed only where Vigie doesn't run: their network is METRICS_NETWORK.
# CrowdSec's metrics are routed over the protection network, shared with Traefik alone
proxy_network_variables = {"metriques": "${METRICS_NETWORK}", "protection": "protection"}
exempt_from_deploy = {"protection"}
for compose in sorted(Path("services").glob("*/compose.yml")):
    stack = compose.parent.name
    if stack == "proxy":
        continue
    text = compose.read_text()
    data = yaml.safe_load(text)
    variable = proxy_network_variables.get(stack, "${PROXY_NETWORK}")
    networks = data.get("networks") or {}
    for key, network in networks.items():
        name = (network or {}).get("name", key)
        if (network or {}).get("external") and name in ("traefik", "proxy"):
            failures.append(f"{compose}: network {key} is the former shared network {name}")
    proxy_keys = {key for key, network in networks.items() if (network or {}).get("name") == variable}
    routed = False
    for name, service in (data.get("services") or {}).items():
        labels = service.get("labels") or []
        if isinstance(labels, dict):
            labels = [f"{key}={value}" for key, value in labels.items()]
        if not any(re.fullmatch(r"traefik\.enable=(true|\$\{[A-Z_]+\})", label) for label in labels):
            continue
        routed = True
        service_networks = service.get("networks") or []
        if isinstance(service_networks, dict):
            service_networks = list(service_networks)
        if not proxy_keys & set(service_networks):
            failures.append(f"{compose}: {name} is routed but not on the network named {variable}")
        if f"traefik.docker.network={variable}" not in labels:
            failures.append(f"{compose}: {name} lacks the label traefik.docker.network={variable}")
        if not any(re.match(r"traefik\.http\.services\.[^.]+\.loadbalancer\.server\.port=", label) for label in labels):
            failures.append(f"{compose}: {name} does not name its port (traefik.http.services.<name>.loadbalancer.server.port)")
    if routed and stack not in exempt_from_deploy:
        deploy = "".join(path.read_text() for path in sorted(compose.parent.rglob("*.yml")) if path != compose)
        if not re.search(r"compose_service_proxy: |tasks_from: proxy", deploy):
            failures.append(f"services/{stack}/deploy.yml: routed, but gives no proxy network (compose_service_proxy)")

routes = yaml.safe_load(Path("inventory/host_vars/bruxelles/traefik.yml").read_text())["traefik_routes"]
for route in routes:
    host = re.sub(r"^[a-z]+://", "", route["url"]).split(":")[0].split("/")[0]
    is_container = not re.fullmatch(r"[0-9.]+", host)
    if is_container and not str(route.get("network", "")).startswith("proxy-"):
        failures.append(f"route {route['name']} goes to the container {host} without a network: proxy-<app>")
    if not is_container and "network" in route:
        failures.append(f"route {route['name']} goes to a LAN address: it has no proxy network")

for failure in failures:
    print(f"error {failure}")
if failures:
    sys.exit(1)
print("ok    every routed app has a proxy network of its own")
PYTHON
