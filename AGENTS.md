# AGENTS.md

Ansible playbooks and Docker Compose files that deploy Alix's self-hosted services. Everything here acts on live servers and public DNS, so read before you run.

## Layout

- `services/<service>/` — one folder per service: `deploy.yml` (playbook), `compose.yml`, and any `*.j2` templates or config it copies.
- `hosts/workstations/mcp.yml` — points the owner's MCP clients (Claude Code, Codex, OpenCode, Antigravity) at MCPHub, run on the workstation itself.
- `hosts/<host>/` — host-level playbooks (packages, networking, `hosts/bruxelles/nextcloud_after_update.yml`); `hosts/bootstrap.yml` and `hosts/replication.yml` apply to several hosts.
- `dns/<zone>.yml` — one playbook per Cloudflare DNS zone (`anneraud.yml`, `xila.yml`, `minitrainstore.yml`, `guenola_sahut.yml`), applied on their own, not by `site.yml`.
- `services/authentification/applications.yml` + `opentofu/zitadel/` — the whole Anneraud Zitadel organization (policies, users from the vault, OIDC applications); see the documentation's Authentification page. A service that needs Zitadel login gets an entry in `opentofu/zitadel/applications.auto.tfvars` and uses `roles/zitadel` from its `deploy.yml` (see `services/vigie/deploy.yml`).
- `opentofu/netbird/` + `services/maillage/configuration.yml` — NetBird's account (groups, policies, networks, routes, DNS, setup keys) and its Zitadel login, applied from the controller; edit the code, never the dashboard.
- `services/<service>/tests/*.yml` — playbook tests that need no host (CI runs them); `services/archive` prepares Paperless's (a TrueNAS app) Zitadel variables to paste, see the documentation's Authentification page ("Applications TrueNAS").
- `inventory/hosts.yml` — hosts, plus one group per service naming the host it runs on (`translate: {hosts: {luxembourg:}}`). Group names use underscores (`status_dera_page`).
- `inventory/host_vars/<host>.yml` (or a folder, `inventory/host_vars/bruxelles/`) — per-host settings: connection, `local_dns_host` / `global_dns_host`, `services_root`, `proxy_network`. Put host facts here, not in playbooks.
- `vault/` — **private submodule** (`Infrastructure_vault`) with Ansible Vault files, one per service: `vault/<service>/vault.yml`, plus `vault/ansible/vault.yml` (sudo password) and `vault/cloudflare/vault.yml`.
- `services/website/website` — the documentation site (https://www.anneraud.fr/documentation/, VitePress, in French), a submodule of its own repository (`Infrastructure_website`, published to GitHub Pages on every push to its `main`). It explains how everything works and how to operate it; `readme.md` only presents the repository and links there. When a change alters how something works or is operated, update the matching page in `src/documentation/` of that repository (`npm run check` before pushing), not the readme.

## Hosts

| Host | Role | Service root | Reverse proxy |
|---|---|---|---|
| `luxembourg` | Cloud VM with a public IP | `/opt/<service>` | Traefik (`services/proxy`), labels on the external `traefik` network |
| `bruxelles` | Home TrueNAS server | `/mnt/Donnees/Applications_chiffrees/<Service>` | Traefik (`services/proxy`), labels on the external `proxy` network; TrueNAS Apps and LAN devices, which can't carry labels, in `inventory/host_vars/bruxelles/traefik.yml` |
| `pristina` | Home machine | — | — |
| `paris` | Desktop client | — | — |

Luxembourg is reachable from the internet: anything published with `ports:` there is public, because Docker bypasses the host firewall. Traefik's ports are published through its own dual-stack `ingress` network (its gateway, `gw_priority`), so IPv6 clients keep their address: keep it that way, an IPv4-only gateway network makes them all look like one Docker address. Keep internal services behind Traefik with the `internal-allowlist@file` middleware instead. Traefik metrics are served on an internal `:8082` entrypoint (not published); Vigie scrapes it, so never expose it with `ports:`. The host and container exporters (`services/metriques`) are never published either: Vigie reaches them in the internal `metriques` network on Luxembourg and through Bruxelles' Traefik behind `internal-allowlist@file`. Traefik's access logs go the other way (Vector, also in `services/metriques`): into Vigie's VictoriaLogs over the same internal `metriques` network on Luxembourg, and from Bruxelles through `https://vigie.anneraud.fr/insert/jsonline` behind the same allowlist.

On hosts of the `protection` group (`protection_enabled`, Luxembourg and Bruxelles), every `web-secure` request goes through CrowdSec's bouncer (`crowdsec@file`, `services/proxy/protection.yml.j2`), and CrowdSec (`services/protection`) reads Traefik's JSON access log from its container output. Its local API stays on the internal `protection` network, never published. Vigie's VictoriaMetrics scrapes its metrics (`:6060`) over the internal `protection-metrics` network on Luxembourg, shared with nothing else: Grafana and the other services stay off it; on Bruxelles, Traefik routes `/metrics` alone to it over the `protection` network, behind `internal-allowlist@file`, never through the `proxy` network. The LAN and VPN ranges come from `internal-allowlist` in `services/proxy/policy.yml` (`internal_networks`): change them there only. CrowdSec and its bouncer also trust Docker's range (`protection_trusted_networks`) and, through a whitelist CrowdSec resolves itself, the addresses of `protection_trusted_hosts` (the home's is dynamic): never write a public address of the hosts into the repository. Public login endpoints get a rate limit (labels on the stacks, `rate_limit` in the Bruxelles route data for TrueNAS Apps); never on internal routes. See the documentation's Sécurité page.

Bruxelles backs up chosen datasets to Google Drive every night (`services/sauvegarde`: a TrueNAS cron job snapshots them and runs restic through rclone); the list is in `inventory/host_vars/bruxelles/sauvegarde.yml`. Its restic password is the only key to the backup: never print it or change it without the owner.

## Tooling

Tools are pinned with uv (`pyproject.toml`, `uv.lock`), OpenTofu with mise (`mise.toml`) and Ansible collections in `requirements.yml`. `mise.toml` also holds the owner's shortcuts (`mise deploy <playbook>` = `mise exec -- uv run ansible-playbook`, `mise preview`, `mise lint`, `mise test`, `mise vault`); keep them in sync when a command below changes.

```bash
uv sync
uv run ansible-galaxy collection install -r requirements.yml   # into .ansible/collections
uv run yamllint .
uv run ansible-lint
.github/scripts/check-compose.sh                               # docker compose config on every service
# CI only (they pull images): .github/scripts/check-traefik-routes.sh, check-vigie.sh, check-protection.sh
(cd roles/compose_service && uv run molecule test)             # runs the role against a local busybox stack (needs Docker)
```

All of them must pass; CI (`.github/workflows/lint.yml`) runs them on every PR and push to `main`. CI has no vault password, so ansible-lint runs against empty placeholder vault files — playbooks must not depend on vault values to parse.

ansible-lint warns `args[module]` on the Cloudflare playbooks: a false positive, `zone` comes from `module_defaults`.

## Conventions

Compose services are deployed with the shared role `roles/compose_service` (see its `defaults/main.yml` and `meta/argument_specs.yml`). A service's `deploy.yml` is only:

```yaml
- name: Deploy Wakapi
  hosts: wakapi                      # the service's inventory group
  become: true
  vars_files:                        # always the ansible vault (sudo password), then the service's, then cloudflare
    - ../../vault/ansible/vault.yml
    - ../../vault/wakapi/vault.yml
    - ../../vault/cloudflare/vault.yml
  roles:
    - role: compose_service
      vars:
        compose_service_name: wakapi
        compose_service_directory: Wakapi   # only when the folder name differs from the service name
        compose_service_user: 568            # also written to .env as USER_ID / GROUP_ID
        compose_service_environment: {...}   # written to .env
        compose_service_files: [{source: config.yml, destination: config/config.yml}]
        compose_service_mounted_files: [repos.sqlite]
        compose_service_dns_records: [{record: wakapi.dera.page}]   # visibility: private for local_dns_host
```

The role creates the folder under the host's `services_root` (permissions only on creation, existing TrueNAS folders keep their ACLs), copies `compose.yml`, writes `.env`, starts the stack and points the DNS records at the host. Stacks are only recreated when their image or configuration changes, and restarted when an extra file changes. Every Compose service uses the role except `services/secrets_xila`, which bootstraps its own TLS certificate and must stay unsealed; keep it hand-written. `site.yml` imports every service playbook (`mise deploy site.yml --limit <host>`); add new services to it.

Rules:

- Bind-mount paths in `compose.yml` must match what `deploy.yml` creates. A missing file mount makes Docker create a directory in its place.
- Pass UID/GID and secrets to Compose through `.env` (`${USER_ID}:${GROUP_ID}`), not hard-coded twice.
- Every long-running container gets `restart: unless-stopped`, databases included.
- Pin image tags (no `latest`, no untagged images); Dependabot (`.github/dependabot.yml`) opens one grouped PR per ecosystem every Monday. It does not cover `requirements.yml` or `.python-version`: update those by hand.
- Ansible style: FQCN modules (`ansible.builtin.copy`), `true`/`false`, `changed_when` on `command`/`shell`, handlers for restarts.
- Lines that can't be split (DNS TXT records, Traefik rules, long commands) get `# yamllint disable-line rule:line-length`. Never put that comment inside a `|` block scalar: it would become part of the file content; wrap the task in `# yamllint disable/enable rule:line-length` instead.
- New public endpoints should also get a Gatus check in `services/etat/anneraud.yml` or `services/etat/dera_page.yml`, and a row in the documentation's Services page (`src/documentation/services.md` of the website).

## Hosts access

- Ansible connects as `ansible` with passwordless sudo; `hosts/bootstrap.yml` sets it up and hardens `sshd` on every host except TrueNAS (`truenas` group, configured in its interface). Never widen `automation_ssh_sources` or `ssh_administrators` in `inventory/group_vars/all.yml` without the owner.
- Runs against hosts go through Semaphore (`services/deploiement`, its key is in `automation_additional_public_keys`) or the owner's laptop; Zitadel provisioning (OpenTofu) still runs from the laptop.
- Hosts that need to reach each other use their own account and key with a forced command (see `hosts/replication.yml`), never the `ansible` account.

## Secrets

- Never decrypt, print or commit vault contents. Vault files are edited with `mise vault <file>`; the password comes from the system keyring through `vault-password-client.py` (`ANSIBLE_VAULT_PASSWORD_FILE` in `mise.toml`). Never read the keyring entry or run that script yourself.
- Changing secrets means two commits: one in the `vault` repo (push it first), then one here updating the submodule pointer. Never point the submodule at a commit that isn't pushed.

## Safety

- Do not run `ansible-playbook` against real hosts, change DNS, or force-push without the owner's explicit go-ahead. Linting and `--syntax-check` are fine.
- `dera.page` (the bare domain) normally belongs to a friend's server; `services/matrix_dera_page/bare_domain.yml` switches it temporarily. Don't add permanent records for it elsewhere.

## Git

- Commit as the repository owner only. Do **not** add `Co-Authored-By`, "Generated with" or any other AI attribution to commits or PR descriptions.
- `main` is protected: every change goes through a PR, CI must pass, and PRs are squash-merged. Work on a branch and open the PR with `gh pr create`.
- Commit messages: short imperative subject (`Fix Star History database path`), body explaining why.
