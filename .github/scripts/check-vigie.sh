#!/usr/bin/env bash
# Lay Vigie out as services/vigie/deploy.yml does, start it with its own
# Compose file next to the exporters of services/metriques (laid out as on
# Luxembourg, in the metrics network), feed VictoriaMetrics sample Traefik
# metrics and check what Grafana provisioned: datasource, dashboards and alert
# rules, that the rules evaluate as expected and that the exporters' metrics
# answer every query of the Hosts dashboard.
# With CHECK_ZFS_POOL set to the name of a healthy ZFS pool on this machine,
# node_exporter must read its state and free space, and no pool alert fires.
set -euo pipefail

directory=$(mktemp -d)
project=check-vigie-$$
network=$project-proxy
metrics_network=$project-metrics
password=check-vigie-password
zfs_pool=${CHECK_ZFS_POOL:-}
compose() {
    docker compose -p "$project" --project-directory "$directory" \
        -f "$directory/compose.yml" -f "$directory/compose.check.yml" "$@"
}
exporters() {
    docker compose -p "$project-metriques" --project-directory "$directory/metriques" "$@"
}
cleanup() {
    status=$?
    if [ "$status" -ne 0 ] && [ -f "$directory/compose.yml" ]; then
        compose logs --no-color --tail 50 || true
        exporters logs --no-color --tail 30 || true
    fi
    compose down --volumes --timeout 5 > /dev/null 2>&1 || true
    exporters down --volumes --timeout 5 > /dev/null 2>&1 || true
    docker network rm "$network" "$metrics_network" protection-metrics > /dev/null 2>&1 || true
    rm -rf "$directory"
    exit "$status"
}
trap cleanup EXIT

# Copy the files and render the templates to the destinations deploy.yml gives them
uv run python - "$directory" > "$directory/layout" <<'EOF'
import sys
from pathlib import Path

import yaml

play = yaml.safe_load(Path("services/vigie/deploy.yml").read_text())[0]
role = next(role for role in play["roles"] if role["role"] == "compose_service")["vars"]
for directory in role.get("compose_service_directories", []):
    print("directory", directory, directory)
for entry in role.get("compose_service_files", []):
    print("file", entry["source"], entry["destination"])
for entry in role.get("compose_service_templates", []):
    print("template", entry["source"], entry["destination"])
EOF
cp services/vigie/compose.yml "$directory/compose.yml"
while read -r kind source destination; do
    mkdir -p "$(dirname "$directory/$destination")"
    case "$kind" in
        directory) mkdir -p "$directory/$destination" ;;
        file) cp "services/vigie/$source" "$directory/$destination" ;;
        template)
            # Placeholder vault values; rules are evaluated every 10 s to keep the check short
            if ! output=$(uv run ansible luxembourg -c local -e "ansible_python_interpreter=$(uv run which python)" \
                -e vigie_home_assistant_webhook_id=check-vigie-webhook \
                -e vigie_grafana_admin_password=$password \
                -e vigie_alert_evaluation_interval=10s \
                -m ansible.builtin.template -a "src=services/vigie/$source dest=$directory/$destination"); then
                echo "$output"
                exit 1
            fi
            ;;
    esac
done < "$directory/layout"
# The exporters, with the files services/metriques/deploy.yml copies
mkdir -p "$directory/metriques"
cp services/metriques/compose.yml "$directory/metriques/"
chmod -R a+rX "$directory"

# Containers run as the current user, who owns the data folders here
cat > "$directory/.env" <<EOF
USER_ID=$(id -u)
GROUP_ID=$(id -g)
PROXY_NETWORK=$network
METRICS_NETWORK=$metrics_network
GRAFANA_ADMIN_PASSWORD=$password
EOF
# As on Luxembourg: in the metrics network, not routed by Traefik
cat > "$directory/metriques/.env" <<EOF
METRICS_ROUTED=false
METRICS_HOST=
METRICS_NETWORK=$metrics_network
EOF
cat > "$directory/compose.check.yml" <<'EOF'
services:
  victoriametrics:
    ports: ["127.0.0.1::8428"]
  grafana:
    ports: ["127.0.0.1::3000"]
EOF
docker network create "$network" > /dev/null
# Shared with CrowdSec, which does not run here: its target is down
docker network create --internal protection-metrics > /dev/null
docker network create --internal "$metrics_network" > /dev/null
exporters up -d --wait --quiet-pull

# VictoriaMetrics must accept the scrape configuration as it is
compose run --rm --no-deps victoriametrics \
    -promscrape.config=/etc/vigie/scrape.yml -dryRun

compose up -d --wait --quiet-pull
metrics="http://$(compose port victoriametrics 8428)"
grafana="http://admin:$password@$(compose port grafana 3000)"

ready=false
for _ in $(seq 60); do
    if curl -fs "$metrics/health" > /dev/null && curl -fs "$grafana/api/health" > /dev/null; then
        ready=true
        break
    fi
    sleep 2
done
if [ "$ready" != true ]; then
    echo "VictoriaMetrics or Grafana did not become healthy within 2 minutes"
    exit 1
fi

# Sample Traefik counters for the last 8 minutes, one point every 30 s:
# app@file answers 9 % of its requests with a 5xx (the error rule must fire)
# and quickly (the latency rule must not); nextcloud@file and matrix-dera-page@docker
# are slow but excluded. The latency rule reads the last 5 minutes, which keep
# at least 20 requests per service for the whole 2-minute poll
now=$(date +%s)
uv run python - "$now" > "$directory/samples.prom" <<'EOF'
import sys

now = int(sys.argv[1])
for step in range(17):
    timestamp = (now - 480 + step * 30) * 1000
    successes, errors = step * 10, step
    for service, code, count in (("app@file", "200", successes), ("app@file", "500", errors),
                                 ("nextcloud@file", "200", successes), ("matrix-dera-page@docker", "200", successes)):
        labels = f'service="{service}",code="{code}",method="GET",protocol="http",host="bruxelles"'
        print(f"traefik_service_requests_total{{{labels}}} {count} {timestamp}")
    for service in ("app@file", "nextcloud@file", "matrix-dera-page@docker"):
        total = successes + errors if service == "app@file" else successes
        labels = f'service="{service}",code="200",method="GET",protocol="http",host="bruxelles"'
        for bound in ("0.1", "0.3", "1.2", "5.0", "+Inf"):
            fast = service == "app@file" or bound in ("5.0", "+Inf")
            print(f'traefik_service_request_duration_seconds_bucket{{{labels},le="{bound}"}} {total if fast else 0} {timestamp}')
        print(f"traefik_service_request_duration_seconds_count{{{labels}}} {total} {timestamp}")
        print(f"traefik_service_request_duration_seconds_sum{{{labels}}} {total * 0.05 if service == 'app@file' else total * 4} {timestamp}")
    # Protection: 80 login requests over the limit on vaultwarden-login@file (the
    # rate limit rule must fire), 160 429 answers on app@file, which has no
    # login rate limit (it must not), and 48 CrowdSec alerts (the spike rule must fire)
    for router, count in (("vaultwarden-login@file", step * 5), ("app@file", step * 10)):
        service = router.replace("-login", "")
        labels = f'router="{router}",service="{service}",code="429",method="POST",protocol="http",host="bruxelles"'
        print(f"traefik_router_requests_total{{{labels}}} {count} {timestamp}")
    labels = 'name="crowdsecurity/http-probing",job="crowdsec",host="luxembourg"'
    print(f"cs_bucket_overflowed_total{{{labels}}} {step * 3} {timestamp}")
EOF
curl -fsS --data-binary "@$directory/samples.prom" "$metrics/api/v1/import/prometheus"
curl -fsS "$metrics/internal/force_flush" > /dev/null

# Every query of the protection dashboards must be valid MetricsQL
uv run python - "$metrics" <<'EOF'
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

failures = []
for name in ("crowdsec.json", "rate_limits.json"):
    panels = json.loads(Path("services/vigie/grafana/dashboards", name).read_text())["panels"]
    for panel in panels:
        for target in panel.get("targets", []):
            query = target["expr"].replace("$host", ".*").replace("$__rate_interval", "2m")
            query = query.replace("$__interval", "1m").replace("$__range", "1h")
            url = sys.argv[1] + "/api/v1/query?" + urllib.parse.urlencode({"query": query})
            try:
                with urllib.request.urlopen(url) as response:
                    status = json.load(response).get("status")
            except urllib.error.HTTPError as error:
                status = error.read().decode()
            if status != "success":
                failures.append(f"{name}, {panel['title']}: {status}")
print("\n".join(failures) or "The protection dashboards' queries are valid")
sys.exit(1 if failures else 0)
EOF

cat > "$directory/check.py" <<'EOF'
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

directory, metrics, zfs_pool, project = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]


def load(name):
    try:
        return json.loads((directory / name).read_text())
    except json.JSONDecodeError:
        return {}


failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


targets = {
    target["labels"].get("job"): (target["scrapeUrl"], target["health"], target["labels"].get("host"))
    for target in load("targets.json").get("data", {}).get("activeTargets", [])
}
urls = {job: url for job, (url, _, _) in targets.items()}
check(
    urls == {
        "traefik-luxembourg": "http://traefik:8082/metrics",
        "traefik-bruxelles": "https://traefik.bruxelles.anneraud.fr/metrics",
        "crowdsec": "http://crowdsec:6060/metrics",
        "node-luxembourg": "http://node-exporter:9100/metrics",
        "containers-luxembourg": "http://cadvisor:8080/metrics",
        "node-bruxelles": "https://metriques.bruxelles.anneraud.fr/node/metrics",
        "containers-bruxelles": "https://metriques.bruxelles.anneraud.fr/containers/metrics",
    },
    f"scrape targets are {urls}",
)
check(targets.get("crowdsec", (None, None, None))[2] == "luxembourg", f"crowdsec target is {targets.get('crowdsec')}")
# Luxembourg's exporters are reached in the metrics network
for job in ("node-luxembourg", "containers-luxembourg"):
    check(targets.get(job, (None, None, None))[1] == "up", f"target {job} is {targets.get(job, (None, None, None))[1]}")

datasource = load("datasource.json")
check(datasource.get("status") == "OK", f"datasource health is {datasource}")

for uid in ("traefik", "crowdsec", "rate-limits"):
    dashboard = load(f"dashboard-{uid}.json").get("dashboard", {})
    check(dashboard.get("uid") == uid, f"dashboard {uid} is missing")
    variables = [variable["name"] for variable in dashboard.get("templating", {}).get("list", [])]
    check("host" in variables, f"dashboard {uid} variables are {variables}")
hosts_dashboard = load("dashboard-hosts.json").get("dashboard", {})
check(hosts_dashboard.get("uid") == "hosts", "dashboard hosts is missing")

groups = load("rules.json").get("data", {}).get("groups", [])


def group_rules(name):
    return {rule["name"]: rule for group in groups if group.get("file") == "Vigie" and group.get("name") == name for rule in group["rules"]}


rules = {rule["name"]: rule for group in groups if group.get("file") == "Vigie" for rule in group["rules"]}
expected_groups = {
    "Traefik": {"Traefik server errors", "Traefik slow responses", "Traefik metrics missing"},
    # Luxembourg, Vigie's host, runs CrowdSec: its rules are rendered
    "Protection": {
        "CrowdSec metrics missing", "CrowdSec bouncer silent", "CrowdSec reads no access log",
        "CrowdSec alert spike", "Login rate limit spike",
    },
    "Hosts": {"Host disk space low", "ZFS pool unhealthy", "Host memory high", "Host CPU high", "Host metrics missing"},
}
for name, expected in expected_groups.items():
    found = set(group_rules(name))
    check(found == expected, f"rules of group {name} are {sorted(found)}")
check(set(rules) == set().union(*expected_groups.values()), f"rules in folder Vigie are {sorted(rules)}")
for name, rule in rules.items():
    check(rule.get("health") == "ok" and not rule.get("lastError"), f"rule {name} health {rule.get('health')}: {rule.get('lastError')}")
# The error rule waits 10 minutes before firing, so pending means its condition holds
errors = rules.get("Traefik server errors", {})
check(errors.get("state") in ("pending", "firing"), f"rule Traefik server errors is {errors.get('state')}")
alerts = [alert["labels"].get("service") for alert in errors.get("alerts", [])]
check(alerts == ["app@file"], f"rule Traefik server errors alerts for {alerts}")
# Annotations are rendered for pending alerts too: labels and values must reach the text
for alert in errors.get("alerts", []):
    summary = alert.get("annotations", {}).get("summary", "")
    check(
        "app@file" in summary and "bruxelles" in summary and "%" in summary
        and "error" not in summary.replace("server error", "") and "no value" not in summary,
        f"rule Traefik server errors summary is {summary!r}",
    )
latency = rules.get("Traefik slow responses", {})
check(latency.get("state") == "inactive", f"rule Traefik slow responses is {latency.get('state')}")


def alerting(name, label, values, words):
    """The rule is pending or firing for exactly these label values, with these words in its summary"""
    rule = rules.get(name, {})
    check(rule.get("state") in ("pending", "firing"), f"rule {name} is {rule.get('state')}")
    found = sorted(alert["labels"].get(label) for alert in rule.get("alerts", []))
    check(found == values, f"rule {name} alerts for {found}")
    for alert in rule.get("alerts", []):
        summary = alert.get("annotations", {}).get("summary", "")
        check(
            all(word in summary for word in words) and "no value" not in summary and "<" not in summary,
            f"rule {name} summary is {summary!r}",
        )


# Its target does not resolve here: up = 0
alerting("CrowdSec metrics missing", "host", ["luxembourg"], ["luxembourg", "cannot be scraped"])
alerting("CrowdSec alert spike", "host", ["luxembourg"], ["luxembourg", "48 alerts"])
alerting("Login rate limit spike", "router", ["vaultwarden-login@file"], ["vaultwarden-login@file", "bruxelles", "80 login"])
# Both wait for CrowdSec to answer, which it does not here
for name in ("CrowdSec bouncer silent", "CrowdSec reads no access log"):
    state = rules.get(name, {}).get("state")
    check(state == "inactive", f"rule {name} is {state}")

hosts = group_rules("Hosts")
expected = expected_groups["Hosts"]
check(set(hosts) == expected, f"rules in group Hosts are {sorted(hosts)}")
for name, rule in hosts.items():
    check(rule.get("health") == "ok" and not rule.get("lastError"), f"rule {name} health {rule.get('health')}: {rule.get('lastError')}")
# Bruxelles' exporters are unreachable here, Luxembourg's are scraped
missing = hosts.get("Host metrics missing", {})
# Grafana lists every series of the rule, scraped ones too (state Normal)
firing = [alert for alert in missing.get("alerts", []) if alert.get("state", "").lower() not in ("normal", "inactive")]
check(missing.get("state") in ("pending", "firing"), f"rule Host metrics missing is {missing.get('state')}")
jobs = sorted(alert["labels"].get("job", alert["labels"].get("exporter")) for alert in firing)
check(jobs == ["containers-bruxelles", "node-bruxelles"],
      f"rule Host metrics missing alerts for {jobs}")
for alert in firing:
    summary = alert.get("annotations", {}).get("summary", "")
    check(alert["labels"].get("job", "") in summary and "cannot be scraped" in summary, f"rule Host metrics missing summary is {summary!r}")
# The pool is ONLINE: its rule is evaluated and does not fire
unhealthy = hosts.get("ZFS pool unhealthy", {})
check(unhealthy.get("state") == "inactive", f"rule ZFS pool unhealthy is {unhealthy.get('state')}")


def query(expression):
    url = f"{metrics}/api/v1/query?" + urllib.parse.urlencode({"query": expression})
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            return json.load(response)
    except Exception as error:
        return {"status": "error", "error": str(error)}


# Every query of the Hosts dashboard parses and, once the exporters have been scraped twice, returns
# series (ZFS ones only with a pool)
panels = [panel for panel in json.loads(Path("services/vigie/grafana/dashboards/hosts.json").read_text())["panels"] if panel["type"] != "row"]
for panel in panels:
    for target in panel.get("targets", []):
        expression = target["expr"].replace("$__rate_interval", "2m").replace("$host", ".*").replace("$app", ".*")
        result = query(expression)
        check(result.get("status") == "success", f"panel {panel['title']}: {result.get('error')}")
        if zfs_pool or not re.search(r"zfs", expression):
            check(bool(result.get("data", {}).get("result")), f"panel {panel['title']} has no data: {expression}")
# Containers are named after their Compose project (app) and container
grafana = query(f'container_memory_working_set_bytes{{host="luxembourg", app="{project}", container="{project}-grafana-1"}}')
check(bool(grafana.get("data", {}).get("result")), f"no memory series for Grafana's container: {grafana}")
if zfs_pool:
    state = query(f'node_zfs_zpool_state{{host="luxembourg", zpool="{zfs_pool}", state="online"}}')
    values = [sample["value"][1] for sample in state.get("data", {}).get("result", [])]
    check(values == ["1"], f"state of the ZFS pool {zfs_pool} is {state}")

print("\n".join(failures))
sys.exit(1 if failures else 0)
EOF

# Poll until every check passes, at most 4 minutes: rates need two scrapes, 30 s apart
failures=""
for _ in $(seq 48); do
    # A failed request leaves an unreadable file: the checks fail and the next round retries
    curl -fsS "$metrics/api/v1/targets" > "$directory/targets.json" || true
    curl -sS "$grafana/api/datasources/uid/victoriametrics/health" > "$directory/datasource.json" || true
    for uid in traefik crowdsec rate-limits hosts; do
        curl -sS "$grafana/api/dashboards/uid/$uid" > "$directory/dashboard-$uid.json" || true
    done
    curl -fsS "$grafana/api/prometheus/grafana/api/v1/rules" > "$directory/rules.json" || true
    if failures=$(uv run python "$directory/check.py" "$directory" "$metrics" "$zfs_pool" "$project"); then
        echo "Vigie provisioned: datasource healthy, dashboards present, exporters scraped, alert rules evaluated as expected"
        exit 0
    fi
    sleep 5
done
echo "$failures"
exit 1
