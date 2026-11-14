provider "gitea" {
  base_url = var.gitea_url
  token    = var.gitea_token
}

# A fine-grained token has a single resource owner, so each GitHub owner gets
# its own provider instance with its own token
provider "github" {
  alias    = "by_owner"
  for_each = var.owners
  owner    = each.key
  token    = var.github_tokens[each.key]
}
