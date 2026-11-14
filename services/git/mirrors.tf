# Every repository of the GitHub owners in mirrors.auto.tfvars is pull-mirrored
# into Gitea, new ones included at each run. Forks are left out: they are other
# people's code. One search per owner and visibility, since the data source
# only returns names: the query tells whether the repositories are private.
locals {
  queries = merge([
    for owner, settings in var.owners : {
      for visibility in ["public", "private"] : "${owner}/${visibility}" => {
        owner   = owner
        private = visibility == "private"
        query   = "${settings.type}:${owner} fork:false is:${visibility}"
      }
    }
  ]...)
}

data "github_repositories" "found" {
  for_each = local.queries
  provider = github.by_owner[each.value.owner]

  query            = each.value.query
  results_per_page = 100
}

# The Gitea repositories already there, to adopt the mirrors made by hand
data "gitea_repositories" "existing" {
  for_each = toset([for owner in values(var.owners) : owner.gitea_owner])

  username = each.key
}

locals {
  # Keyed by lower-cased GitHub full name: a case-only rename on GitHub changes nothing
  github_repositories = merge([
    for key, query in local.queries : {
      for full_name in data.github_repositories.found[key].full_names : lower(full_name) => {
        full_name    = full_name
        github_owner = query.owner
        name         = split("/", full_name)[1]
        private      = query.private
      }
    }
  ]...)

  aliases          = { for full_name, name in var.aliases : lower(full_name) => name }
  excluded_imports = { for full_name, id in var.excluded_imports : lower(full_name) => id }

  # Gitea names are unique regardless of case: look the existing ones up lower-cased
  existing = {
    for owner, found in data.gitea_repositories.existing : owner => {
      for repository in found.repositories : lower(repository.name) => repository
    }
  }

  candidates = {
    for key, repository in local.github_repositories : key => merge(repository, {
      gitea_owner = var.owners[repository.github_owner].gitea_owner
      # The existing Gitea repository under the GitHub name, and under the
      # former name of a repository renamed on GitHub since its mirror was made
      by_name = lookup(local.existing[var.owners[repository.github_owner].gitea_owner], lower(repository.name), null)
      by_alias = (
        contains(keys(local.aliases), key)
        ? lookup(local.existing[var.owners[repository.github_owner].gitea_owner], lower(local.aliases[key]), null)
        : null
      )
    })
  }

  # A mirror under the GitHub name comes first: once renamed, the alias no
  # longer finds anything
  mirrors = {
    for key, mirror in local.candidates : key => merge(mirror, {
      existing = (
        try(mirror.by_name.mirror, false) ? mirror.by_name
        : mirror.by_alias != null ? mirror.by_alias
        : mirror.by_name
      )
    })
  }

  # Only an existing mirror is adopted: a repository of the same name that is
  # not a mirror, or that excluded_imports names, would be the wrong one
  adopted = {
    for key, mirror in local.mirrors : key => tostring(mirror.existing.id)
    if try(mirror.existing.mirror && mirror.existing.id != lookup(local.excluded_imports, key, -1), false)
  }

  # Tests turn imports off: OpenTofu cannot import with a mocked provider
  imports = var.import_existing ? local.adopted : {}

  # Adopted mirrors whose Gitea name is not their GitHub name (a former name, or
  # another case): mirrors.yml renames them through Gitea's API, since the
  # provider resets a mirror's settings on any update
  renames = {
    for key, mirror in local.mirrors : key => {
      owner = mirror.gitea_owner
      from  = mirror.existing.name
      to    = mirror.name
    }
    if contains(keys(local.adopted), key) && mirror.existing.name != mirror.name
  }

  # Mirrors whose name is taken in Gitea by a repository that is not adopted
  clashes = {
    for key, mirror in local.mirrors : key => "${mirror.gitea_owner}/${mirror.existing.name}"
    if mirror.existing != null && !contains(keys(local.adopted), key)
  }
}

import {
  for_each = local.imports
  to       = gitea_repository.mirror[each.key]
  id       = each.value
}

resource "gitea_repository" "mirror" {
  for_each = local.mirrors

  username = each.value.gitea_owner
  # An adopted mirror keeps its current name here (renamed by mirrors.yml); a
  # new one takes the GitHub name
  name    = each.value.existing != null ? each.value.existing.name : each.value.name
  private = each.value.private

  mirror                       = true
  migration_clone_address      = "https://github.com/${each.value.full_name}.git"
  migration_service            = "github"
  migration_service_auth_token = var.github_tokens[each.value.github_owner]
  migration_mirror_interval    = var.mirror_interval

  # A repository gone from GitHub (deleted, made a fork…) keeps its mirror, archived
  archive_on_destroy = true

  lifecycle {
    # Creating it would fail on the name anyway: say which repository is in the way
    precondition {
      condition     = !contains(keys(local.clashes), each.key)
      error_message = "Gitea already has ${lookup(local.clashes, each.key, "")}, which is not adopted as the mirror of ${each.value.full_name} (not a mirror, or listed in excluded_imports). Delete or rename it in Gitea, or add an alias."
    }

    # The provider never reads the migration settings back and sends every
    # setting on update, so an adopted mirror would be replaced or have its
    # settings reset. OpenTofu only creates mirrors, keeps their visibility in
    # line with GitHub, and records archive_on_destroy, which an import leaves
    # unset (and an unset value deletes the repository on destroy).
    ignore_changes = [
      username,
      name,
      description,
      website,
      default_branch,
      default_merge_style,
      auto_init,
      repo_template,
      issue_labels,
      gitignores,
      license,
      readme,
      has_issues,
      has_wiki,
      has_pull_requests,
      has_projects,
      ignore_whitespace_conflicts,
      allow_merge_commits,
      allow_rebase,
      allow_rebase_explicit,
      allow_squash_merge,
      allow_manual_merge,
      autodetect_manual_merge,
      archived,
      mirror,
      migration_clone_addresse,
      migration_clone_address,
      migration_service,
      migration_service_auth_username,
      migration_service_auth_password,
      migration_service_auth_token,
      migration_milestones,
      migration_releases,
      migration_issue_labels,
      migration_mirror_interval,
      migration_lfs,
      migration_lfs_endpoint,
      source_template,
      source_template_items,
    ]
  }
}

# Renamed by mirrors.yml after the apply, so every mirror ends up with its
# GitHub name
output "renames" {
  description = "Adopted mirrors whose Gitea name differs from their GitHub name: owner, from, to."
  value       = local.renames
}
