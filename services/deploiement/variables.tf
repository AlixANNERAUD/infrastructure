variable "semaphore_url" {
  description = "Semaphore, without the API path (reached over the VPN: internal allowlist)."
  type        = string
  default     = "https://deploiement.anneraud.fr"
}

variable "semaphore_token" {
  description = "API token of Semaphore's local administrator, created by configuration.yml for this run."
  type        = string
  sensitive   = true
}

variable "ssh_private_key" {
  description = "Private key Semaphore connects to the hosts with, as the ansible user (keys/ansible on Bruxelles)."
  type        = string
  sensitive   = true
}

variable "vault_password" {
  description = "Password of the Ansible vault the playbooks read their secrets from."
  type        = string
  sensitive   = true
}

variable "state_passphrase" {
  description = "Passphrase the state encryption key is derived from (at least 16 characters)."
  type        = string
  sensitive   = true
}

variable "state_path" {
  description = "Path of the encrypted state file."
  type        = string
  default     = "../../vault/deploiement/opentofu.tfstate"
}

variable "repository_url" {
  description = "Repository Semaphore clones (public: no key)."
  type        = string
  default     = "https://github.com/AlixANNERAUD/Infrastructure.git"
}

variable "playbooks_root" {
  description = "Root of the repository, where the playbooks are listed (tests point it at a fixture)."
  type        = string
  default     = "../.."
}

variable "excluded_playbooks" {
  description = <<-EOT
    Playbooks Semaphore cannot run: those that need OpenTofu or the owner's
    computer. The OpenTofu configurations (services/*/configuration.yml,
    services/git/mirrors.yml...) are not matched in the first place.
  EOT
  type        = set(string)
  default = [
    # Provisions a TrueNAS App's Zitadel login with OpenTofu, and prints it
    "services/archive/deploy.yml",
  ]
}

variable "preview_schedule" {
  description = "When the preview of site.yml runs (cron), to show what drifted from the repository; empty disables it."
  type        = string
  default     = "0 4 * * *"
}
