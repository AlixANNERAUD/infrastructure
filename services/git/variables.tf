variable "gitea_url" {
  description = "Gitea instance, without the API path (reached over the VPN: internal allowlist)."
  type        = string
  default     = "https://git.anneraud.fr"
}

variable "gitea_token" {
  description = "Access token of the Gitea user alix_anneraud (write:repository, write:organization, read:user)."
  type        = string
  sensitive   = true
}

variable "github_tokens" {
  description = "Read-only GitHub token per GitHub owner (Contents and Metadata), keyed like owners."
  type        = map(string)
  sensitive   = true

  validation {
    condition     = alltrue([for owner in keys(var.owners) : length(lookup(var.github_tokens, owner, "")) > 0])
    error_message = "Every GitHub owner in owners needs a token in github_tokens."
  }
}

variable "state_passphrase" {
  description = "Passphrase the state encryption key is derived from (at least 16 characters)."
  type        = string
  sensitive   = true
}

variable "state_path" {
  description = "Path of the encrypted state file."
  type        = string
  default     = "../../vault/git/opentofu.tfstate"
}

variable "owners" {
  description = "GitHub owners whose repositories are mirrored, keyed by GitHub login (mirrors.auto.tfvars)."
  type = map(object({
    # user or org: the GitHub search qualifier for this owner
    type = string
    # Gitea user or organization that holds the mirrors (must exist)
    gitea_owner = string
  }))

  validation {
    condition     = alltrue([for owner in values(var.owners) : contains(["user", "org"], owner.type)])
    error_message = "An owner's type must be user or org."
  }

  # An empty map would archive every mirror
  validation {
    condition     = length(var.owners) > 0
    error_message = "owners is empty: OpenTofu would archive every mirror."
  }
}

variable "aliases" {
  description = "Existing Gitea mirror name per GitHub full name, for repositories renamed on GitHub since their mirror was made."
  type        = map(string)
  default     = {}
}

variable "excluded_imports" {
  description = <<-EOT
    Gitea repository id that must not be adopted, per GitHub full name: a Gitea
    repository that has the mirror's name but is not a mirror of that GitHub
    repository. While it exists, the plan fails and asks to delete or rename it.
  EOT
  type        = map(number)
  default     = {}
}

variable "mirror_interval" {
  description = "How often Gitea pulls each new mirror (Go duration; 0 disables it)."
  type        = string
  default     = "8h0m0s"
}

variable "import_existing" {
  description = "Import the existing Gitea mirrors (off only in tests: OpenTofu cannot import with a mocked provider)."
  type        = bool
  default     = true
}
