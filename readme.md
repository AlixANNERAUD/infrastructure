<h1 align="center">Infrastructure</h1>

<p align="center">
  <strong>The infrastructure I designed, built and run for my family, entirely as code.</strong><br>
  Two servers, about 45 self-hosted services, single sign-on, a mesh VPN, intrusion prevention and
  full observability: deployed with Ansible, Docker Compose and OpenTofu, tested in CI.
</p>

<p align="center">
  <a href="https://github.com/AlixANNERAUD/Infrastructure/actions/workflows/lint.yml"><img alt="CI" src="https://github.com/AlixANNERAUD/Infrastructure/actions/workflows/lint.yml/badge.svg"></a>
  <a href="https://etat.anneraud.fr/"><img alt="Status page" src="https://img.shields.io/badge/status-etat.anneraud.fr-brightgreen"></a>
  <a href="https://www.anneraud.fr/documentation/"><img alt="Documentation" src="https://img.shields.io/badge/docs-anneraud.fr-blue"></a>
  <a href="https://alix.anneraud.fr/"><img alt="Author" src="https://img.shields.io/badge/author-Alix%20ANNERAUD-informational"></a>
</p>

<p align="center">
  <img alt="Ansible" src="https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white">
  <img alt="Docker Compose" src="https://img.shields.io/badge/Docker%20Compose-2496ED?logo=docker&logoColor=white">
  <img alt="OpenTofu" src="https://img.shields.io/badge/OpenTofu-FFDA18?logo=opentofu&logoColor=black">
  <img alt="Traefik" src="https://img.shields.io/badge/Traefik-24A1C1?logo=traefikproxy&logoColor=white">
  <img alt="TrueNAS" src="https://img.shields.io/badge/TrueNAS%20SCALE-0095D5?logo=truenas&logoColor=white">
  <img alt="Grafana" src="https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white">
  <img alt="GitHub Actions" src="https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white">
</p>

---

This repository is the production infrastructure of my family's digital life (passwords,
documents, photos, home automation, chat), hosted on hardware we own rather than in someone
else's cloud. I treat it like software: every service, route, DNS record, login, alert and
dashboard is a reviewed file, linted and tested in CI, then applied with one command. It is also
where I practise what I care about as an engineer: security by default, observability, and
automation that is boring to operate.

## At a glance

| | |
| --- | --- |
| **Servers** | A TrueNAS SCALE home server (ZFS) and a cloud VM, joined by a NetBird mesh VPN |
| **Services** | About 45: Nextcloud, Vaultwarden, Paperless-ngx, Jellyfin, Home Assistant, Matrix Synapse, Gitea, Open WebUI… ([full list](https://www.anneraud.fr/documentation/services)) |
| **Deployment** | 20 Compose stacks from this repository through one shared Ansible role; TrueNAS apps routed by it |
| **Identity** | Zitadel single sign-on, its organization and OIDC applications provisioned with OpenTofu |
| **Edge** | Traefik v3, wildcard Let's Encrypt certificates over Cloudflare DNS, CrowdSec, per-client rate limits |
| **Observability** | VictoriaMetrics, VictoriaLogs and Grafana, alerts to phones, an MCP server for LLM queries |
| **Quality** | 8 CI jobs, including ones that boot the real stacks; weekly Dependabot updates |

## Architecture

```mermaid
flowchart LR
    user([Visitors and family]) -->|HTTPS| cloudflare[Cloudflare DNS]
    cloudflare --> lux
    cloudflare --> bxl
    subgraph lux [Cloud VM]
        traefik_lux[Traefik + CrowdSec] --> vpn[NetBird]
        traefik_lux --> vigie[VictoriaMetrics, VictoriaLogs, Grafana]
        traefik_lux --> gatus[Gatus status page]
    end
    subgraph bxl [TrueNAS home server]
        traefik_bxl[Traefik] --> apps[Nextcloud, Vaultwarden, Paperless, Jellyfin, Home Assistant…]
        traefik_bxl --> zitadel[Zitadel SSO]
    end
    vpn <-->|WireGuard mesh| bxl
    vigie -.->|scrapes metrics, receives logs| bxl
```

## Engineering highlights

- **Tested like application code.** CI does not stop at linting: it boots Traefik with its real
  routes, CrowdSec and its bouncer (and checks that a scanner gets banned and an IPv6 client keeps
  its own address), and VictoriaMetrics with Grafana, feeding synthetic metrics and checking that
  every dashboard query is valid and every alert fires when it should. Ansible roles have Molecule
  scenarios, OpenTofu configurations are validated and tested.
- **Secure by default.** Private services only answer the LAN and the VPN; nothing internal is
  published, metrics and APIs stay on internal Docker networks; containers drop the capabilities they do not need and
  read the Docker socket through read-only proxies; secrets live in Ansible Vault in a private
  submodule and the OpenTofu state is encrypted; SSH keys are restricted by source network and
  forced commands.
- **Identity as code.** The whole Zitadel organization (policies, users, OIDC clients for each
  service) is OpenTofu, and services pick up their client credentials at deploy time.
- **Observable.** Host, container, Traefik and CrowdSec metrics, Traefik's access logs, Grafana
  dashboards and alert rules are all provisioned from this repository; Grafana's MCP server gives
  an LLM read-only access to them for investigations.
- **Small, repeatable building blocks.** Every service is a folder with a playbook and a Compose
  file, deployed by one shared role that creates folders, writes secrets, starts the stack and
  publishes its DNS records; toolchains are pinned with uv and mise; deployments also run from
  Semaphore on the server itself.

## Documentation

Everything about how it works and how to operate it is on **[www.anneraud.fr](https://www.anneraud.fr/documentation/)** (in French), written from this repository ([source](https://github.com/AlixANNERAUD/Infrastructure_website)):

| Page | Answers |
| --- | --- |
| [Architecture](https://www.anneraud.fr/documentation/architecture) | Which server does what, how a request reaches a service, how single sign-on works |
| [Network](https://www.anneraud.fr/documentation/reseau) and [DNS](https://www.anneraud.fr/documentation/dns) | How sites, the VPN and Docker networks are addressed and named |
| [Security](https://www.anneraud.fr/documentation/securite) | Which protections a request goes through; operating CrowdSec; secrets and the vault |
| [Deployment](https://www.anneraud.fr/documentation/deploiement) | How a change goes from this repository to the servers; the automation account; Semaphore |
| [Single sign-on](https://www.anneraud.fr/documentation/authentification) | What OpenTofu owns in Zitadel, accounts, connecting a service, TrueNAS apps |
| [Monitoring](https://www.anneraud.fr/documentation/supervision) | Gatus and Vigie: metrics, access logs, dashboards, alerts, LogsQL queries |
| [Backups](https://www.anneraud.fr/documentation/sauvegardes) | Where data is copied, replication, how to restore |
| [AI assistants](https://www.anneraud.fr/documentation/assistants) | MCPHub, the workstations' clients, Grafana's MCP server |
| [Services](https://www.anneraud.fr/documentation/services) | Every service with its access, host and deployment |

## Repository layout

```
inventory/        # hosts, one group per service naming its host, per-host settings
services/<name>/  # one folder per service: deploy.yml (playbook), compose.yml, templates
roles/            # compose_service (every stack), opentofu, zitadel
opentofu/zitadel/ # the Zitadel organization, its users and OIDC applications
hosts/            # host-level playbooks: bootstrap, replication, workstations
dns/              # one playbook per Cloudflare DNS zone
site.yml          # every service, host by host
vault/            # private submodule: Ansible Vault files and the encrypted OpenTofu state
.github/          # CI: lint, Molecule, OpenTofu, and checks that boot the real stacks
```

## Working on it

```bash
mise install && mise run setup                 # pinned Ansible, OpenTofu, linters and collections
mise preview site.yml --limit <host>           # what would change, without changing it
mise deploy services/<service>/deploy.yml      # deploy one service
mise vault vault/<service>/vault.yml           # edit a service's secrets
mise lint && mise test                         # the CI checks that need no server
```

Conventions for changes (and for coding agents) are in [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE).
