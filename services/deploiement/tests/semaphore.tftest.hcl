# Which templates OpenTofu plans for the repository's playbooks, without
# Semaphore: the provider is mocked
mock_provider "semaphoreui" {}

variables {
  semaphore_token  = "test-token"
  ssh_private_key  = "test-key"
  vault_password   = "test-password"
  state_passphrase = "test-state-passphrase"
  state_path       = "test.tfstate"
}

run "templates" {
  command = plan

  assert {
    condition = alltrue([
      for key in ["site.yml/run", "site.yml/preview", "services/maison/deploy.yml/run", "hosts/bootstrap.yml/preview", "dns/anneraud.yml/run"] :
      contains(keys(semaphoreui_project_template.playbook), key)
    ])
    error_message = "A playbook of the repository has no run or preview template."
  }

  assert {
    condition = !anytrue([
      for key in keys(semaphoreui_project_template.playbook) :
      startswith(key, "hosts/workstations/") || startswith(key, "services/archive/") || strcontains(key, "configuration.yml")
    ])
    error_message = "A playbook Semaphore cannot run has a template."
  }

  assert {
    condition = (
      semaphoreui_project_template.playbook["site.yml/preview"].name == "site (aperçu)"
      && join(" ", semaphoreui_project_template.playbook["site.yml/preview"].arguments) == "--check --diff"
      && semaphoreui_project_template.playbook["services/maison/deploy.yml/run"].name == "maison"
      && semaphoreui_project_template.playbook["services/maison/deploy.yml/run"].arguments == null
      && semaphoreui_project_template.playbook["hosts/luxembourg/update.yml/run"].name == "hosts/luxembourg/update"
    )
    error_message = "The templates are not named after their playbook, or the preview is not --check --diff."
  }

  assert {
    condition     = length(semaphoreui_project_schedule.preview) == 1
    error_message = "The nightly preview is not scheduled."
  }
}

run "no_schedule" {
  command = plan

  variables {
    preview_schedule = ""
  }

  assert {
    condition     = length(semaphoreui_project_schedule.preview) == 0
    error_message = "An empty schedule still schedules the preview."
  }
}
