variable "management_url" {
  description = "URL of the NetBird management API."
  type        = string
  default     = "https://netbird.anneraud.fr"
}

variable "netbird_token" {
  description = "Personal access token of the NetBird service user OpenTofu acts as (admin role)."
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
  default     = "../../vault/vpn/opentofu.tfstate"
}

variable "zitadel_client_id" {
  description = "Client id of NetBird's application in Zitadel (opentofu/zitadel)."
  type        = string
}

variable "zitadel_client_secret" {
  description = "Client secret of NetBird's application in Zitadel (opentofu/zitadel)."
  type        = string
  sensitive   = true
}
