# Semaphore's project, written here rather than in its interface: a project,
# the repository, the inventory, the keys, and two task templates per playbook
# (a preview with --check --diff, and a run), new playbooks included at each
# run of configuration.yml.
locals {
  # The playbooks, by kind; hosts/workstations runs on the owner's computers
  playbooks = {
    for path in setsubtract(setunion(
      fileset(var.playbooks_root, "site.yml"),
      fileset(var.playbooks_root, "services/*/deploy.yml"),
      fileset(var.playbooks_root, "hosts/*.yml"),
      [for path in fileset(var.playbooks_root, "hosts/*/*.yml") : path if !startswith(path, "hosts/workstations/")],
      fileset(var.playbooks_root, "dns/*.yml"),
    ), var.excluded_playbooks) :
    path => {
      # site, maison, hosts/bootstrap, hosts/luxembourg/update, dns/anneraud
      name = (
        path == "site.yml" ? "site"
        : startswith(path, "services/") ? split("/", path)[1]
        : trimsuffix(path, ".yml")
      )
      view = startswith(path, "hosts/") ? "hosts" : startswith(path, "dns/") ? "dns" : "services"
    }
  }

  # No arguments is null, not an empty list: the provider reads an empty list
  # back as null and fails the apply ("inconsistent result after apply")
  modes = {
    run     = { suffix = "", arguments = null }
    preview = { suffix = " (aperçu)", arguments = ["--check", "--diff"] }
  }

  templates = merge([
    for path, playbook in local.playbooks : {
      for mode, settings in local.modes : "${path}/${mode}" => merge(playbook, settings, { path = path })
    }
  ]...)

  views = {
    services = { title = "Services", position = 0 }
    hosts    = { title = "Hôtes", position = 1 }
    dns      = { title = "DNS", position = 2 }
  }
}

resource "semaphoreui_project" "infrastructure" {
  name = "Infrastructure"
}

resource "semaphoreui_project_key" "none" {
  project_id = semaphoreui_project.infrastructure.id
  name       = "none"
  none       = {}
}

resource "semaphoreui_project_key" "ansible" {
  project_id = semaphoreui_project.infrastructure.id
  name       = "ansible"
  ssh = {
    login       = "ansible"
    private_key = var.ssh_private_key
  }
}

resource "semaphoreui_project_key" "vault" {
  project_id = semaphoreui_project.infrastructure.id
  name       = "vault"
  login_password = {
    login    = ""
    password = var.vault_password
  }
}

# Public: cloned without a key. The private vault submodule is cloned with the
# read-only token services/deploiement/deploy.yml hands to git in the container
resource "semaphoreui_project_repository" "infrastructure" {
  project_id = semaphoreui_project.infrastructure.id
  name       = "Infrastructure"
  url        = var.repository_url
  branch     = "main"
  ssh_key_id = semaphoreui_project_key.none.id
}

resource "semaphoreui_project_inventory" "hosts" {
  project_id = semaphoreui_project.infrastructure.id
  name       = "inventory/hosts.yml"
  ssh_key_id = semaphoreui_project_key.ansible.id
  file = {
    path          = "inventory/hosts.yml"
    repository_id = semaphoreui_project_repository.infrastructure.id
  }
}

# Templates need one; the playbooks take everything from the repository and the vault
resource "semaphoreui_project_environment" "empty" {
  project_id = semaphoreui_project.infrastructure.id
  name       = "Aucune variable"
}

resource "semaphoreui_project_view" "view" {
  for_each = local.views

  project_id = semaphoreui_project.infrastructure.id
  title      = each.value.title
  position   = each.value.position
}

resource "semaphoreui_project_template" "playbook" {
  for_each = local.templates

  project_id     = semaphoreui_project.infrastructure.id
  repository_id  = semaphoreui_project_repository.infrastructure.id
  inventory_id   = semaphoreui_project_inventory.hosts.id
  environment_id = semaphoreui_project_environment.empty.id
  view_id        = semaphoreui_project_view.view[each.value.view].id

  name      = "${each.value.name}${each.value.suffix}"
  playbook  = each.value.path
  arguments = each.value.arguments
  # A run can still be limited to a host (--limit) when it is started
  allow_override_args_in_task = true

  vaults = [{
    name = ""
    password = {
      vault_key_id = semaphoreui_project_key.vault.id
    }
  }]
}

# Each night, a preview of everything: what it would change is what drifted
# from the repository (a TrueNAS App edited by hand, a network lost...)
resource "semaphoreui_project_schedule" "preview" {
  count = var.preview_schedule == "" ? 0 : 1

  project_id  = semaphoreui_project.infrastructure.id
  template_id = semaphoreui_project_template.playbook["site.yml/preview"].id
  name        = "Aperçu nocturne"
  cron_format = var.preview_schedule
  enabled     = true
}
