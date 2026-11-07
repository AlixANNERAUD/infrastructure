# Infrastructure

This repository contains the infrastructure code and documentation for deploying and managing my personnal services.

## Inventory

Hosts and the service-to-host mapping are in [inventory/hosts.yml](inventory/hosts.yml); per-host settings are in [inventory/host_vars/](inventory/host_vars/).

## Services

| Name                                                                   | Description                                  | Access  | Server     | Deployment   | Status                                                                                                                             |
| ---------------------------------------------------------------------- | -------------------------------------------- | ------- | ---------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| [Accueil](https://wwww.anneraud.fr/)                                   | Services homepage                            | Public  | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_accueil/uptimes/30d/badge.svg)                                        |
| [Bichon](https://archive-courriel.anneraud.fr/)                         | Email archive                                | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_bichon/uptimes/30d/badge.svg)                                        |
| [Bitwarden](https://bitwarden.anneraud.fr/)                            | Password manager (Vaultwarden)               | Public  | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_bitwarden/uptimes/30d/badge.svg)                                      |
| [Collabora](https://collabora.anneraud.fr/)                            | Online office suite                           | Public  | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_collabora/uptimes/30d/badge.svg)                                     |
| [Nuage](https://nuage.anneraud.fr/)                                    | Cloud storage and collaboration (Nextcloud)  | Public  | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_nuage-(nextcloud)/uptimes/30d/badge.svg>)                            |
| [Automatisation](https://automatisation.anneraud.fr)                   | Workflow automation (n8n)                    | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_automatisation-(n8n)/uptimes/30d/badge.svg>)                         |
| [Maison](https://maison.anneraud.fr/)                                  | Home automation (Home Assistant)             | Public  | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_maison-(home-assistant)/uptimes/30d/badge.svg>)                      |
| [Médiathèque](https://mediatheque.anneraud.fr/)                        | Media server (Jellyfin)                      | Public  | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_médiathèque-(jellyfin)/uptimes/30d/badge.svg>)                       |
| [MeTube](https://metube.anneraud.fr/)                                  | Video downloader                              | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_metube/uptimes/30d/badge.svg)                                         |
| [MeshCentral](https://parc.anneraud.fr/)                               | Remote device management                      | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_meshcentral/uptimes/30d/badge.svg)                                    |
| [Téléchargement](https://telechargement.anneraud.fr/)                  | Download manager (qBittorrent)               | Private | Bruxelles  | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_téléchargement-(qbittorrent)/uptimes/30d/badge.svg>)                 |
| [Matrix](https://matrix.anneraud.fr/)                                  | Matrix server (Synapse)                      | Public  | Bruxelles  | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_matrix-(synapse)/uptimes/30d/badge.svg>)                             |
| [Archive](https://archive.anneraud.fr/)                                | Document management (Paperless-ngx)          | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_archive-(paperless-ngx)/uptimes/30d/badge.svg>)                      |
| [Statistiques](https://s.anneraud.fr/)                                 | Analytics (Umami)                            | Public  | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_statistiques-(umami)/uptimes/30d/badge.svg>)                         |
| [Notes](https://notes.anneraud.fr/)                                    | Documentation (Docmost)                      | Public  | Bruxelles  | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_notes-(docmost)/uptimes/30d/badge.svg>)                              |
| [Déploiement](https://deploiement.anneraud.fr/)                         | Ansible web UI (Semaphore)                   | Private | Bruxelles  | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_déploiement-(semaphore)/uptimes/30d/badge.svg>) |
| [Assistant](https://assistant.anneraud.fr/)                            | AI assistant (Open WebUI)                    | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_assistant-(open-webui)/uptimes/30d/badge.svg>)                       |
| [Recherche](https://recherche.anneraud.fr/)                            | Search engine (SearXNG)                      | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_recherche-(searxng)/uptimes/30d/badge.svg>)                           |
| [Authentification](https://authentification.anneraud.fr/)              | Identity provider (Zitadel)                  | Public  | Bruxelles  | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_authentification-(zitadel)/uptimes/30d/badge.svg>)                   |
| [PDF](https://pdf.anneraud.fr/)                                        | PDF management (BentoPDF)                    | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_pdf-(bentopdf)/uptimes/30d/badge.svg>)                               |
| [Mini Train Store](https://minitrainstore.fr/)                         | Business management (Odoo)                   | Public  | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_mini-train-store-(odoo)/uptimes/30d/badge.svg>)                      |
| [Git](https://git.anneraud.fr/)                                        | Git forge (Gitea)                            | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_git-(gitea)/uptimes/30d/badge.svg>)                                  |
| [Finances](https://finances.anneraud.fr/)                              | Personal finance manager (Firefly III)       | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_finances-(firefly-iii)/uptimes/30d/badge.svg>)                       |
| [Importateur finances](https://importeur-finances.anneraud.fr/)        | Finance data importer (Firefly III importer) | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_importateur-finances-(firefly-iii-importer)/uptimes/30d/badge.svg>)  |
| [Recettes](https://recettes.anneraud.fr/)                              | Recipe manager (Mealie)                      | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_recettes-(mealie)/uptimes/30d/badge.svg>)                            |
| [Portefolio Alix](https://alix.anneraud.fr/)                           | Personal portfolio (GitHub Pages)            | Public  | -          | -            | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_portefolio-alix-(github-pages)/uptimes/30d/badge.svg>)               |
| [Radarr](https://radarr.anneraud.fr/)                                  | Movie collection manager                     | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_radarr/uptimes/30d/badge.svg)                                         |
| [Sonarr](https://sonarr.anneraud.fr/)                                  | TV show collection manager                   | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_sonarr/uptimes/30d/badge.svg)                                         |
| [Prowlarr](https://prowlarr.anneraud.fr/)                              | Indexer manager                              | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_prowlarr/uptimes/30d/badge.svg)                                       |
| [Bazarr](https://bazarr.anneraud.fr/)                                  | Subtitle manager                             | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_bazarr/uptimes/30d/badge.svg)                                         |
| [Jellyseerr](https://jellyseerr.anneraud.fr/)                          | Media request manager                        | Private | Bruxelles  | TrueNAS Apps | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_jellyseerr/uptimes/30d/badge.svg)                                     |
| [Wakapi](https://wakapi.anneraud.fr)                                   | Coding time tracker                          | Public  | Bruxelles  | Ansible      | ![Status](https://etat.anneraud.fr/api/v1/endpoints/services_wakapi/uptimes/30d/badge.svg)                                         |
| [Translation](https://translate.anneraud.fr/)                          | Translation platform (Tolgee)                | Public  | Luxembourg | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/services_translation-(tolgee)/uptimes/30d/badge.svg>)                         |
| [Vault Xila](https://vault.xila.dev/ui/)                                | Xila signing service (OpenBao)               | Private | Bruxelles  | Ansible      | ![Status](https://etat.anneraud.fr/api/v1/endpoints/administration_vault-xila/uptimes/30d/badge.svg)                              |
| [Proxy Bruxelles](https://traefik.bruxelles.anneraud.fr/)              | Reverse proxy (Traefik)                      | Private | Bruxelles  | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_proxy-bruxelles-(traefik)/uptimes/30d/badge.svg>)              |
| [DNS dynamique Bruxelles](https://ddns-updater.bruxelles.anneraud.fr/) | Dynamic DNS updater                          | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_dns-dynamique-bruxelles-(ddns-updater)/uptimes/30d/badge.svg>) |
| [Bruxelles console](https://bruxelles.anneraud.fr/)                    | Server management (TrueNAS)                  | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_bruxelles-console-(truenas)/uptimes/30d/badge.svg>)            |
| [Conteneurs Bruxelles](https://conteneurs.bruxelles.anneraud.fr/)      | Container management (Portainer)             | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_conteneurs-bruxelles-(portainer)/uptimes/30d/badge.svg>)       |
| [Databasus](https://databasus.anneraud.fr/)                            | Database management (Adminer)                | Private | Bruxelles  | TrueNAS Apps | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_databasus/uptimes/30d/badge.svg>)                    |
| [Cockpit (Luxembourg)](https://cockpit.luxembourg.anneraud.fr/)        | Server management (Cockpit)                  | Private | Luxembourg | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_cockpit-(luxembourg)/uptimes/30d/badge.svg>)                      |
| [Vigie](https://vigie.anneraud.fr/)                                    | Monitoring (VictoriaMetrics, Grafana)        | Private | Luxembourg | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_vigie-(grafana)/uptimes/30d/badge.svg>)                           |
| Protection (Luxembourg)                                                | Intrusion prevention (CrowdSec)              | Private | Luxembourg | Ansible      | -                                                                                                                                  |
| [État](https://etat.anneraud.fr/)                                      | Service status page                          | Public  | Luxembourg | Ansible      | -                                                                                                                                  |
| [VPN](https://netbird.anneraud.fr/)                                    | Virtual private network (Netbird)            | Public  | Luxembourg | Ansible      | ![Status](<https://etat.anneraud.fr/api/v1/endpoints/administration_vpn-(netbird)/uptimes/30d/badge.svg>)                          |
| [VPN console](https://netbird.anneraud.fr/admin/)                      | VPN administration console                   | Public  | Luxembourg | Ansible      | ![Status](https://etat.anneraud.fr/api/v1/endpoints/administration_vpn-(netbird)/uptimes/30d/badge.svg)                              |
| [Matrix](https://matrix.insa.lol/)                                     | Decentralized communication platform         | Public  | Luxembourg | Ansible      | -                                                                                                                                  |
| [Status (dera.page)](https://status.dera.page/)                        | Service status page                          | Public  | Luxembourg | Ansible      | -                                                                                                                                  |

## Deployment

Install [uv](https://docs.astral.sh/uv/) and [mise](https://mise.jdx.dev/), then the pinned tools (Ansible, ansible-lint, yamllint, OpenTofu for Zitadel) and Ansible collections:

```bash
mise install
mise run setup
```

Common commands are mise tasks (`mise tasks` lists them). They run with the tools from `mise.toml` on `PATH`, so OpenTofu is there for the Zitadel role. Arguments are passed on to the command:

```bash
mise deploy services/<service_name>/deploy.yml   # deploy one service
mise deploy site.yml --limit bruxelles           # everything on one host (or everything without --limit)
mise preview site.yml --limit bruxelles          # what would change (--check --diff), without changing it
mise vault vault/<service_name>/vault.yml        # edit a vault file
mise lint                                        # yamllint, ansible-lint, docker compose config
mise test                                        # Molecule scenarios of the roles (needs Docker)
```

`mise deploy …` is short for `mise run deploy …` and for `mise exec -- uv run ansible-playbook …`.

## Ansible account

Ansible connects to every host as `ansible`: SSH keys only, passwordless sudo, locked password. The authorized keys (`automation_public_keys` in `inventory/group_vars/all.yml`) are the laptop's (`automation_laptop_public_key`, written in the file so that Semaphore can run the bootstrap too) plus the other controllers' keys listed in `automation_additional_public_keys` (Semaphore's, see below). Each is accepted only from the networks in `automation_ssh_sources`, and no other key is kept in `authorized_keys`. The exception is on Bruxelles (TrueNAS): the controllers' keys, which connect from containers on the `proxy` network, are also accepted from that network's current subnet. To rotate the laptop's key, generate a new one (`ssh-keygen -t ed25519-sk` for a hardware-backed key is recommended), replace `automation_laptop_public_key` with its public key and run `mise deploy hosts/bootstrap.yml` on every host (and update the TrueNAS Authorized Keys line it prints), using the old key for that run.

Set it up, or update it, with:

```bash
mise deploy hosts/bootstrap.yml --limit <host>                                # existing host
mise deploy hosts/bootstrap.yml --limit <host> -u <you> --ask-become-pass     # new host, added to the inventory first
```

The playbook also hardens `sshd` (no passwords, no root login, only `ansible` and `ssh_administrators`). It refuses to run if the current connection doesn't come from an allowed network. When a host can't be reached, or sudo needs a password nobody provided, it prints the commands to run on that host by hand and skips it.

**TrueNAS (Bruxelles)** manages users and `sshd` in its own interface, which would undo changes made over SSH. The playbook only checks it (reachable, every key with its `from=` restriction, passwordless sudo, password login off) and prints what to change in the interface.

### Replication

`hosts/replication.yml` gives each client in the `replication` group a `replication` account and key, and installs a forced command on Bruxelles that runs one TrueNAS replication task, so the TrueNAS API key never leaves Bruxelles. Once, before deploying it:

1. Deploy: `mise deploy hosts/replication.yml`. Until the `replication` user exists in TrueNAS, it explains how to create it.
2. Paste the `command="…",restrict ssh-ed25519 …` lines it prints into that user's *Authorized Keys*; it prints them only while they are missing.

## Deployment with Semaphore

[Semaphore](https://semaphoreui.com/) (`services/deploiement`, https://deploiement.anneraud.fr, private) runs the playbooks from Bruxelles. It is deployed with `mise deploy services/deploiement/deploy.yml`, which also generates the SSH key Semaphore connects to the hosts with (`keys/ansible` in the service folder) and prints its public key. Its secrets are in `vault/deploiement/vault.yml`: the admin account (`deploiement_admin_login`, `deploiement_admin_name`, `deploiement_admin_email`, `deploiement_admin_password`), `deploiement_access_key_encryption` and `deploiement_vault_repository_token`. The last one lets Semaphore clone the private `Infrastructure_vault` submodule: create it in GitHub > Settings > Developer settings > Fine-grained personal access tokens, with *Only select repositories* > `Infrastructure_vault` and the repository permission *Contents: Read-only*, an expiry, and a reminder to rotate it before then (update the vault and run the deployment again). The deployment gives it to git in the container through a credential helper limited to that repository (`gitconfig` and `git-credentials` in the service folder, mode `0600`); without it, the deployment still works and prints this step. Generate the encryption key with `head -c32 /dev/urandom | base64` (it encrypts the keys stored in Semaphore: losing it makes them unreadable). The `SEMAPHORE_ADMIN_*` variables only create the admin on the first start: changing them in the vault later does not change the account, use the interface. The database is an embedded SQLite file in `data/` of the service folder. `keys/ansible` on the host stays there as the recovery copy of Semaphore's private key (mode `0600`, owned by the container user). Keep it: if it is deleted, the next deploy generates a different key pair, which has to be authorized and pasted again.

People log in through Zitadel ("Zitadel" button, application `deploiement` in `opentofu/zitadel/applications.auto.tfvars`), next to the local admin, which stays as the fallback: Semaphore deploys this repository, so it must not depend on Zitadel. Semaphore finds an account by email and refuses a Zitadel login whose email belongs to a local account: give the local admin another email (Users) before the first Zitadel login, then make the account Zitadel creates an admin from the local one. The client is provisioned when the playbook runs from the laptop with mise; Semaphore's own runs keep the previous client (no tofu in its container).

Once, to authorize Semaphore on the hosts:

1. Add the printed public key to `automation_additional_public_keys` in `inventory/group_vars/all.yml`, then run `mise deploy hosts/bootstrap.yml`.
2. On TrueNAS, add the same key as a line of the `ansible` user's *Authorized Keys* (bootstrap prints the exact lines). Semaphore's SSH connections to Bruxelles itself come from its container's address on the `proxy` network (not NATed), which has no fixed subnet: on Bruxelles its key is accepted from the LAN and VPN plus the current subnet of `proxy`, read when bootstrap runs. If the `proxy` network is ever recreated, run `mise deploy hosts/bootstrap.yml --limit bruxelles` again and update that line. On the other hosts, the key is accepted from the LAN and VPN only.

Once, in the Semaphore interface:

1. Create the project `Infrastructure`.
2. Key store, add:
   - `ansible`: type SSH, login `ansible`, the content of `keys/ansible` (read it on Bruxelles, it is never committed);
   - `vault`: type Login with password, empty login, the Ansible Vault password (it is only used to decrypt the vault files);
   - `none`: type None, to clone the public repository.
3. Repositories: `https://github.com/AlixANNERAUD/Infrastructure.git`, branch `main`, key `none` (the repository is public). Semaphore updates submodules when it clones; the private vault submodule is cloned with the read-only token that the deployment gives git in the container (see above), nothing to configure here. It installs the collections of the root `requirements.yml` by itself.
4. Inventory: type File, path `inventory/hosts.yml` (relative to the repository), SSH key `ansible`. Ansible reads `host_vars` and `group_vars` next to the inventory file, so `inventory/host_vars/` and `inventory/group_vars/` are picked up.
5. Task templates, for `site.yml` and for each `services/<service>/deploy.yml` (and `hosts/*.yml` if wanted), each in two variants, with the vault password `vault`:
   - preview: CLI args `["--check", "--diff"]`;
   - run: no extra arguments.

Semaphore runs the ansible-core bundled in its image (2.20) while CI lints with 2.21: check the first `--check` run for differences.

Zitadel provisioning (OpenTofu) still runs from the laptop.

## Structure

```
inventory/              # Hosts, groups and per-host settings
roles/                  # Reusable roles (compose_service, ...)
services/
  <service>/            # One folder per deployable stack
    deploy.yml          # Ansible playbook
    compose.yml         # Docker Compose file
    ...                 # Templates and configuration it copies
hosts/                  # Host-level playbooks (bootstrap, replication, hosts/<host>/...)
dns/                    # One playbook per Cloudflare DNS zone
site.yml                # Deploys every service (DNS zones are applied with dns/*.yml)
vault/                  # Private submodule with encrypted secrets
.github/                # CI workflows and check scripts
```

## Protection

Every request to the `web-secure` entrypoint of a Traefik whose host is in the `protection` group (Luxembourg for now) goes through CrowdSec's bouncer, internal routes included. CrowdSec (`services/protection`) reads Traefik's JSON access log from its container output through a read-only Docker socket proxy, detects scans, brute force and known CVE probes with the hub's `crowdsecurity/traefik` collection (which includes `crowdsecurity/base-http-scenarios` and `crowdsecurity/http-cve`), and bans the address for 4 hours; it also receives the community blocklist. Its local API is only reachable by Traefik over the internal `protection` network. The bouncer ([crowdsec-bouncer-traefik-plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin), `crowdsec@file` from `services/proxy/protection.yml.j2`) refreshes the banned addresses every 15 s, answers 403 to them, and lets everything through while CrowdSec is down. Behind Cloudflare it checks the visitor's address (the rightmost `X-Forwarded-For` address that is not Cloudflare's).

The LAN and the VPN (the networks of `internal-allowlist` in `services/proxy/policy.yml`) are never banned: they are in CrowdSec's `internal` allowlist, which drops alerts and refuses decisions on them, and the bouncer lets them through whatever CrowdSec says.

Public login pages are also rate limited per client address, on both hosts (POST requests to the login paths only, so app sync is not limited; Traefik answers 429 past the limit): `rate_limit` on a route in `inventory/host_vars/bruxelles/traefik.yml` for the TrueNAS Apps, and labels for the stacks of this repository: Zitadel on Bruxelles (with the limits of that same file, written to its `.env`), Tolgee and Netbird's login on Luxembourg.

Prerequisites, once:

- `vault/protection/vault.yml` holds `protection_bouncer_key`, the key Traefik's bouncer authenticates with (`openssl rand -hex 32`), and optionally `protection_enrollment_key` to enroll the engine in the [CrowdSec console](https://app.crowdsec.net) (then accept it there and run `docker restart crowdsec`). `services/proxy/deploy.yml` loads this vault on every host, so it must exist.
- Deploy Traefik first, then CrowdSec: `mise deploy services/proxy/deploy.yml --limit luxembourg`, then `mise deploy services/protection/deploy.yml`.
- Traefik downloads the plugin from plugins.traefik.io when it starts. If that fails, every route of the host answers 404 (its routers miss the `crowdsec` middleware): restart Traefik (`docker restart traefik`) once the plugin site is back, or remove the host from the `protection` group and deploy Traefik again. Dependabot does not update the plugin version in `services/proxy/compose.yml`.
- The bouncer key is registered when CrowdSec starts and only if it is not registered yet. To change it: update the vault, `docker exec crowdsec cscli bouncers delete traefik`, deploy CrowdSec then Traefik, and `docker restart traefik`.

On the host:

```bash
docker exec crowdsec cscli decisions list                 # current bans
docker exec crowdsec cscli decisions delete --ip <address> # unban
docker exec crowdsec cscli alerts list                     # what was detected
docker exec crowdsec cscli allowlists inspect internal     # never banned
```

An unban reaches Traefik within 15 s. To add another host, add it to the `protection` group in `inventory/hosts.yml` and deploy Traefik then CrowdSec there.

## Vigie

Vigie (`services/vigie`) runs on Luxembourg: VictoriaMetrics (3 months of retention, 30 s scrape interval) and Grafana at `https://vigie.anneraud.fr/`, reachable only through Traefik's internal allowlist. It scrapes the metrics of both Traefik instances (Luxembourg and Bruxelles) and Grafana alerts a Home Assistant webhook on 5xx errors, high latency and unreachable targets. Grafana login goes through Zitadel (role `vigie-admin` maps to Grafana `Admin`, everyone else is `Viewer`); the local admin login stays available as a fallback.

Prerequisites:

- `vault/vigie/vault.yml` holds `vigie_grafana_admin_password` and `vigie_home_assistant_webhook_id`.
- Home Assistant has an automation with a webhook trigger whose id is `vigie_home_assistant_webhook_id`, with `local_only: false` (Grafana calls it through `maison.anneraud.fr` from Luxembourg, not from the home network).
- `vigie_grafana_admin_password` only applies on Grafana's first start, when it creates its database. To rotate it afterwards, run `docker exec -it vigie-grafana-1 grafana cli admin reset-admin-password <new password>` on Luxembourg, then update the vault.
- `vault/authentification/vault.yml` holds `zitadel_automation_token` and `zitadel_state_passphrase`. Without them, the deploy goes on with OAuth off and only the local admin login. If provisioning fails, Grafana keeps the Zitadel login of the previous deploy (OAuth stays off when there was none). When the apply changes the applications, commit `vault/authentification/opentofu.tfstate` in the vault repository.
- The deploy provisions the Zitadel application with OpenTofu, so run it with `mise deploy services/vigie/deploy.yml` (mise puts `tofu` on `PATH`). A missing `tofu` means the playbook was run without mise.
- The Bruxelles scrape goes from Luxembourg to Bruxelles over Netbird and relies on Bruxelles' Traefik internal allowlist accepting the VPN range.

## MCPHub

MCPHub (`services/mcphub`) runs on Bruxelles at `https://mcphub.anneraud.fr/`, behind Traefik's internal allowlist, in database mode with its own PostgreSQL (backed up by Databasus through the `databases` network). People log in through Zitadel (application `mcphub` in `opentofu/zitadel/applications.auto.tfvars`, provisioned by the deploy, which passes the client id and secret to MCPHub); the local `admin` login stays available as a fallback.

Prerequisites:

- `vault/mcphub/vault.yml` (`mise vault:create vault/mcphub/vault.yml`) holds `mcphub_database_password`, `mcphub_jwt_secret`, `mcphub_better_auth_secret` (`openssl rand -hex 32` each) and `mcphub_admin_password` (used only when MCPHub creates its first user).
- Deploy with `mise deploy services/mcphub/deploy.yml` (OpenTofu must be on `PATH`). Without the Zitadel credentials, only the local admin login is available.
- A first Zitadel login creates a regular MCPHub user named after the email (`alix@anneraud.fr`). Make it an administrator once from the local `admin` account (Users). Each user can then connect their own account to servers that use OAuth ("Connect" on the server), and servers are shared through their visibility (`private`, `group` or `public`).

### MCP clients

`mise deploy hosts/workstations/mcp.yml` points the workstation's MCP clients at MCPHub (`https://mcphub.anneraud.fr/mcp`, not `/mcp/$smart`, whose tool search needs pgvector and an embedding service MCPHub does not have), so every model reaches the same servers whatever its provider: Claude Code (through its CLI, user scope), Codex (`~/.codex/config.toml`), OpenCode (`~/.config/opencode/opencode.json`) and Antigravity (`~/.gemini/config/mcp_config.json`). Other settings of those files are kept; an OpenCode file with comments must lose them first. No key is written: the clients log in through MCPHub's OAuth, so its OAuth server must be enabled in MCPHub's settings. Restart the clients afterwards. Every enabled tool reaches the model's context: keep only the tools needed enabled on each MCPHub server (Paperless's `archive` server: its read tools only). The workstation must be on the LAN or Netbird (internal allowlist).

## TrueNAS apps

Apps installed in TrueNAS's interface on Bruxelles keep their configuration there, login through Zitadel included: TrueNAS can only replace an app's settings section as a whole (passwords and keys included), so this repository does not write it. A service's playbook provisions its Zitadel application and writes the environment variables to paste instead.

Paperless (`services/archive`): `mise deploy services/archive/deploy.yml` prints the three entries to add in TrueNAS → Apps → paperless-ngx → Edit → Additional Environment Variables, both with container `paperless`: `PAPERLESS_APPS`, with its value, and `PAPERLESS_SOCIALACCOUNT_PROVIDERS`, whose value holds the client secret and is written alone to `~/.config/infrastructure/zitadel/archive-providers.json` (0600) rather than printed, to copy into the Value field, and `PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS=false`: Paperless never links a Zitadel login to an existing account by itself, so this refuses unlinked logins instead of creating empty duplicate accounts. Keep the other entries; Paperless restarts when saved. Run it again only when the Zitadel application changes. The client secret is then visible to whoever can edit the app in TrueNAS. Existing Paperless users link their account once: log in with their Paperless password, then Profile → Connect a social account → Zitadel.

Each playbook below provisions the Zitadel organization first (like `services/authentification/applications.yml`): commit `vault/authentification/opentofu.tfstate` in the vault repository afterwards. Run it again only when the Zitadel application changes. A client secret pasted in TrueNAS is visible to whoever can edit the app there.

MeshCentral (`services/parc`), in order:

1. `mise deploy services/parc/deploy.yml` writes the `authStrategies` entry of MeshCentral's default domain, with the client secret, to `~/.config/infrastructure/zitadel/parc-authentication.json` (0600). Login strategies are entries of MeshCentral's own `config.json`, in the app's `meshcentral-data` storage (`/opt/meshcentral/meshcentral-data/config.json` in the container), not app settings; the app's setup script keeps them.
2. Add that `authStrategies` key inside `domains` → `""` of `config.json`, keep the rest, and restart the app. The login page shows a Zitadel button next to the password form.
3. MeshCentral never links a Zitadel login to an existing account: each person's first Zitadel login creates a new account (`~oidc:` followed by their Zitadel id), which sees no device and cannot create device groups (`newAccountsRights: [nonewgroups]`). From the local administrator, give it the device groups (or user groups) of the person's old account, and Full Administrator in its server permissions for the owner: MeshCentral only reads groups from a flat list claim, and Zitadel sends its roles as an object, so no role is mapped. Old accounts can go once moved; keep the local administrator as the fallback.

Radarr (`services/films`), in order:

1. `mise deploy services/films/deploy.yml` prints the entries to add in TrueNAS → Apps → radarr → Edit → Additional Environment Variables: `RADARR__AUTH__METHOD=Oidc`, `RADARR__AUTH__OIDCAUTHORITY`, `RADARR__AUTH__OIDCCLIENTID`, `RADARR__AUTH__OIDCUSERIDENTIFIER` and `RADARR__SERVER__TRUSTEDNETWORKS=172.16.0.0/12`, and writes the value of `RADARR__AUTH__OIDCCLIENTSECRET` to `~/.config/infrastructure/zitadel/radarr.secret`. Keep the other entries; the app restarts when saved.
2. Log in with Zitadel. Radarr has a single user: only the organization's owner in `zitadel_users` (`owner: true`) gets in, matched on their verified email. The trusted networks are the Docker networks, so the app reads Traefik's forwarded scheme (its redirect URI is then https) and the client's real address. Keep Authentication Required (Settings → General) on Enabled: with Disabled for Local Addresses, a request carrying a forwarded LAN address from those networks would get in without logging in.

The OIDC login replaces its login form. To fall back to it (Zitadel down), remove the `RADARR__AUTH__METHOD` entry: the form and its password come back from `config.xml`. API keys (Prowlarr, Jellyseerr, Bazarr) are not affected.

## Zitadel

OpenTofu (`opentofu/zitadel/`) owns the whole Anneraud organization: the organization itself (the instance's default), its domain `anneraud.fr`, its login, password, lockout, domain and label policies, its users and their roles, and the projects and OIDC applications of `applications.auto.tfvars`. The instance defaults are not managed, so the ZITADEL organization's admin stays a working fallback whatever the code does. Apply it with `mise deploy services/authentification/applications.yml`; deploys that need an application (Vigie) apply it too. The state is encrypted in `vault/authentification/opentofu.tfstate`: commit it in the vault repository after each change.

`vault/authentification/vault.yml` holds:

- `zitadel_automation_token`: personal access token of the `opentofu` service user of the ZITADEL organization, a manager of the instance with IAM_OWNER (Default settings → Managers).
- `zitadel_state_passphrase`: passphrase of the state (`openssl rand -base64 32`).
- `zitadel_smtp_host` (`host:port`), `zitadel_smtp_user`, `zitadel_smtp_password`: SMTP2GO credentials for Zitadel's emails, sent from `authentification@anneraud.fr`. Without a host, Zitadel sends no email.
- `zitadel_users`: the people, keyed by username, kept out of the public repository. The role refuses to run without them: an empty list would delete every user.

```yaml
zitadel_users:
  alix:
    email: alix@anneraud.fr
    first_name: Alix
    last_name: Anneraud
    owner: true                 # ORG_OWNER of Anneraud
    temporary_password: true    # written to ~/.config/infrastructure/zitadel/alix.password, changed at first login
    roles: {Vigie: [vigie-admin]}
    service_accounts: {nextcloud: Alix ANNERAUD}   # user metadata nextcloud_account, for linking existing accounts
  camille:                      # example
    email: camille@anneraud.fr  # an Infomaniak redirect to their own inbox
    first_name: Camille
    last_name: Example
    service_accounts: {nextcloud: Camille EXAMPLE}
```

Users without `temporary_password` get Zitadel's invitation email. Both only happen when the user is created: setting `temporary_password` on an existing user changes nothing in Zitadel (reset the password from the console instead). Logins read `<username>@anneraud.fr`.

A service deployed by this repository gets its login from the role's `login` entry point in its playbook's `pre_tasks`; the client id and secret come back as `zitadel_login_client_id` and `zitadel_login_client_secret`, for its `.env`. They are empty without the Zitadel credentials, and keep the previous deploy's values when provisioning fails:

```yaml
- name: Get MCPHub's Zitadel login
  ansible.builtin.include_role:
    name: zitadel
    tasks_from: login
  vars:
    zitadel_login_application: mcphub                         # key in applications.auto.tfvars
    zitadel_login_environment_file: "{{ services_root }}/MCPHub/.env"
    zitadel_login_client_id_variable: OIDC_CLIENT_ID          # names in that .env
    zitadel_login_client_secret_variable: OIDC_CLIENT_SECRET  # omitted for PKCE clients
```

For a service managed outside this repository, add an entry to `applications.auto.tfvars` (`authentication = "client_secret"` and `configured_in` when the service needs a secret pasted in) and run `mise deploy services/authentification/applications.yml`: it prints the issuer, client id and `configured_in`, and writes client secrets to `~/.config/infrastructure/zitadel/<application>.secret`.

## Vault

The vault password lives in the system keyring (Secret Service on Linux, Keychain on macOS, Credential Locker on Windows). `mise.toml` points Ansible at `vault-password-client.py`, which reads it from there. The first time on a machine, the first command that needs it asks for it, checks it against `vault/ansible/vault.yml` and stores it. Nothing to source.

```bash
mise vault vault/<service>/vault.yml            # edit (EDITOR, e.g. in mise.local.toml: [env] EDITOR = "zed --wait")
mise exec -- uv run ansible-vault view vault/<service>/vault.yml
./vault-password-client.py --forget             # after changing the password, or to remove it from this machine
```

`ANSIBLE_VAULT_PASSWORD`, when set, takes precedence over the keyring (for machines without one).
