# Which mirrors OpenTofu plans, without GitHub or Gitea: both providers are
# mocked and each search returns the repositories below. The Gitea listings
# need every attribute; only id, name and mirror matter
mock_provider "gitea" {}

# One mock per provider instance, as the configuration has one per owner
mock_provider "github" {
  alias    = "by_owner"
  for_each = toset(["Example", "example-org"])
}

variables {
  gitea_token      = "test-gitea-token"
  github_tokens    = { Example = "test-example-token", example-org = "test-organization-token" }
  state_passphrase = "test-state-passphrase"
  state_path       = "test.tfstate"
  import_existing  = false

  owners = {
    Example     = { type = "user", gitea_owner = "example" }
    example-org = { type = "org", gitea_owner = "Organization" }
  }
  aliases          = { "Example/Renamed" = "Former_name" }
  excluded_imports = {}
}

override_data {
  target = data.github_repositories.found["Example/public"]
  values = { full_names = ["Example/Tool", "Example/Renamed", "Example/fresh-project"] }
}

override_data {
  target = data.github_repositories.found["Example/private"]
  values = { full_names = ["Example/Secret"] }
}

override_data {
  target = data.github_repositories.found["example-org/public"]
  values = { full_names = ["example-org/core"] }
}

override_data {
  target = data.github_repositories.found["example-org/private"]
  values = { full_names = [] }
}

override_data {
  target = data.gitea_repositories.existing["example"]
  values = {
    repositories = [
      { id = 1, name = "TOOL", mirror = true, archived = false, clone_url = "", created = "", default_branch = "main", description = "", fork = false, forks = 0, full_name = "", html_url = "", open_issues = 0, private = false, size = 0, ssh_url = "", stars = 0, updated = "", watchers = 0, website = "" },
      { id = 2, name = "Former_name", mirror = true, archived = false, clone_url = "", created = "", default_branch = "main", description = "", fork = false, forks = 0, full_name = "", html_url = "", open_issues = 0, private = false, size = 0, ssh_url = "", stars = 0, updated = "", watchers = 0, website = "" },
      { id = 4, name = "notes", mirror = false, archived = false, clone_url = "", created = "", default_branch = "main", description = "", fork = false, forks = 0, full_name = "", html_url = "", open_issues = 0, private = false, size = 0, ssh_url = "", stars = 0, updated = "", watchers = 0, website = "" },
      { id = 3, name = "Secret", mirror = true, archived = false, clone_url = "", created = "", default_branch = "main", description = "", fork = false, forks = 0, full_name = "", html_url = "", open_issues = 0, private = false, size = 0, ssh_url = "", stars = 0, updated = "", watchers = 0, website = "" },
    ]
  }
}

override_data {
  target = data.gitea_repositories.existing["Organization"]
  values = {
    repositories = [{ id = 10, name = "Core", mirror = true, archived = false, clone_url = "", created = "", default_branch = "main", description = "", fork = false, forks = 0, full_name = "", html_url = "", open_issues = 0, private = false, size = 0, ssh_url = "", stars = 0, updated = "", watchers = 0, website = "" }]
  }
}

run "searches" {
  command = plan

  assert {
    condition = { for key, query in local.queries : key => query.query } == {
      "Example/public"      = "user:Example fork:false is:public"
      "Example/private"     = "user:Example fork:false is:private"
      "example-org/public"  = "org:example-org fork:false is:public"
      "example-org/private" = "org:example-org fork:false is:private"
    }
    error_message = "The searches are not one per owner and visibility, forks excluded."
  }
}

run "mirrors" {
  command = plan

  assert {
    condition     = toset(keys(gitea_repository.mirror)) == toset(["example/tool", "example/renamed", "example/fresh-project", "example/secret", "example-org/core"])
    error_message = "The mirrors are not keyed by lower-cased GitHub full name."
  }

  assert {
    condition     = gitea_repository.mirror["example/secret"].private && !gitea_repository.mirror["example/tool"].private
    error_message = "A mirror's visibility does not follow its search."
  }

  assert {
    condition     = gitea_repository.mirror["example/renamed"].name == "Former_name"
    error_message = "The alias does not keep the mirror's former name."
  }

  # Existing mirrors keep their name, whatever its case
  assert {
    condition     = gitea_repository.mirror["example/tool"].name == "TOOL" && gitea_repository.mirror["example-org/core"].name == "Core"
    error_message = "An adopted mirror does not keep its existing name."
  }

  assert {
    condition     = gitea_repository.mirror["example/fresh-project"].name == "fresh-project" && gitea_repository.mirror["example-org/core"].username == "Organization"
    error_message = "A new mirror does not get its GitHub name under the owner's Gitea account."
  }

  assert {
    condition     = gitea_repository.mirror["example/secret"].migration_clone_address == "https://github.com/Example/Secret.git"
    error_message = "The clone address is not the GitHub repository."
  }

  assert {
    condition = (
      nonsensitive(gitea_repository.mirror["example/secret"].migration_service_auth_token) == "test-example-token"
      && nonsensitive(gitea_repository.mirror["example-org/core"].migration_service_auth_token) == "test-organization-token"
    )
    error_message = "A mirror does not pull with its owner's token."
  }

  assert {
    condition     = alltrue([for mirror in values(gitea_repository.mirror) : mirror.mirror && mirror.archive_on_destroy && mirror.migration_service == "github"])
    error_message = "A repository is not a GitHub mirror archived on destroy."
  }

  assert {
    condition     = local.adopted == { "example/tool" = "1", "example/renamed" = "2", "example/secret" = "3", "example-org/core" = "10" }
    error_message = "The existing mirrors are not the ones adopted."
  }
}

# A Gitea repository with a mirror's name that is not a mirror, or is excluded,
# is not adopted, and the plan stops before creating anything
run "excluded_import" {
  command = plan

  variables {
    excluded_imports = { "Example/Secret" = 3 }
  }

  assert {
    condition     = !contains(keys(local.adopted), "example/secret") && contains(keys(local.adopted), "example/tool")
    error_message = "The excluded repository is adopted."
  }

  expect_failures = [gitea_repository.mirror]
}

# Gitea names ignore case: a new mirror named like a repository that is not a
# mirror would fail, so the plan stops and names it
run "existing_repository_not_a_mirror" {
  command = plan

  variables {
    aliases = { "Example/fresh-project" = "Notes" }
  }

  assert {
    condition     = local.clashes == { "example/fresh-project" = "example/notes" }
    error_message = "A repository that is not a mirror is not reported in the way."
  }

  expect_failures = [gitea_repository.mirror]
}
