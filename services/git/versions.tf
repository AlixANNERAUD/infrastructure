terraform {
  # Provider for_each (one GitHub provider per owner, each with its own token)
  # needs OpenTofu 1.9
  required_version = ">= 1.9"

  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "= 0.8.1"
    }
    github = {
      source  = "integrations/github"
      version = "= 6.13.0"
    }
  }

  # The state holds the GitHub tokens Gitea pulls private repositories with:
  # it lives in the private vault repository
  backend "local" {
    path = var.state_path
  }
}
