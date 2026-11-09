variable "state_path" {
  description = "Encrypted state file, in the vault repository (vault/trousseau/opentofu.tfstate)."
  type        = string
}

variable "state_passphrase" {
  description = "Passphrase of the state's encryption (trousseau_state_passphrase)."
  type        = string
  sensitive   = true
}

variable "address" {
  description = "OpenBao's address, also the base of its login redirects."
  type        = string
}

variable "automation_secret_id" {
  description = "Secret id of the deploiement AppRole (trousseau_automation_secret_id)."
  type        = string
  sensitive   = true
}

variable "zitadel_issuer" {
  description = "Zitadel's OIDC issuer."
  type        = string
  default     = "https://authentification.anneraud.fr"
}

variable "oidc_client_id" {
  description = "Client id of the trousseau application in Zitadel; empty leaves the Zitadel login out."
  type        = string
  default     = ""
}

variable "oidc_client_secret" {
  description = "Client secret of the trousseau application in Zitadel."
  type        = string
  default     = ""
  sensitive   = true
}

variable "administrator_email" {
  description = "Verified Zitadel email allowed to log in (trousseau_administrator_email)."
  type        = string
  sensitive   = true
}

variable "automation_ssh_sources" {
  description = "Networks the ansible account's certificates work from (automation_ssh_sources)."
  type        = list(string)
}

variable "user_certificate_ttl" {
  description = "Validity of the users' certificates, in seconds: a working day."
  type        = number
  default     = 16 * 3600
}

variable "host_certificate_ttl" {
  description = "Validity of the hosts' certificates, in seconds: two years, renewed by hosts/bootstrap.yml."
  type        = number
  default     = 2 * 365 * 24 * 3600
}
