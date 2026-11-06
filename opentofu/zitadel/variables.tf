variable "zitadel_domain" {
  description = "Domain of the Zitadel instance."
  type        = string
  default     = "authentification.anneraud.fr"
}

variable "zitadel_port" {
  description = "Port of the Zitadel instance."
  type        = string
  default     = "443"
}

variable "zitadel_insecure" {
  description = "Connect without TLS (only for the throwaway Zitadel in Molecule)."
  type        = bool
  default     = false
}

variable "organization_name" {
  description = "Name of the organization OpenTofu creates and owns."
  type        = string
  default     = "Anneraud"
}

variable "organization_domain" {
  description = "Primary domain of the organization: logins read <user>@<domain>."
  type        = string
  default     = "anneraud.fr"
}

variable "zitadel_token" {
  description = "Personal access token of the IAM_OWNER service account in the ZITADEL organization."
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
  default     = "../../vault/authentification/opentofu.tfstate"
}

variable "smtp_host" {
  description = "SMTP server with its port (host:port); empty sends no emails."
  type        = string
  default     = ""
}

variable "smtp_user" {
  description = "SMTP user."
  type        = string
  default     = ""
}

variable "smtp_password" {
  description = "SMTP password."
  type        = string
  sensitive   = true
  default     = ""
}

variable "users" {
  description = "People of the organization, keyed by username (from the vault)."
  type = map(object({
    email      = string
    first_name = string
    last_name  = string
    # ORG_OWNER of the organization
    owner = optional(bool, false)
    # Random password changed at first login, instead of an invitation email
    temporary_password = optional(bool, false)
    # Roles per project name: {Vigie = ["vigie-admin"]}
    roles = optional(map(list(string)), {})
    # Account id per service that predates Zitadel: {nextcloud = "Camille EXAMPLE"}
    service_accounts = optional(map(string), {})
  }))

  validation {
    condition     = length(var.users) > 0
    error_message = "users is empty: OpenTofu would delete every user. Set zitadel_users in vault/authentification/vault.yml."
  }
}

variable "applications" {
  description = "OIDC applications, keyed by application name."
  type = map(object({
    project = string
    roles = optional(list(object({
      key          = string
      display_name = string
    })), [])
    redirect_uris    = list(string)
    post_logout_uris = optional(list(string), [])
    # pkce: public client (no secret); client_secret: confidential client
    # sending its secret with HTTP Basic; client_secret_post: in the request
    # body (Better Auth, as in MCPHub)
    authentication = optional(string, "pkce")
    # Where the owner pastes the client id and secret, for services managed outside this repository
    configured_in = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for application in values(var.applications) : contains(["pkce", "client_secret", "client_secret_post"], application.authentication)])
    error_message = "authentication must be pkce, client_secret or client_secret_post."
  }

  validation {
    condition     = alltrue([for application in values(var.applications) : length(application.redirect_uris) > 0])
    error_message = "Every application needs at least one redirect URI."
  }
}
