variable "truenas_endpoint" {
  description = "TrueNAS WebSocket API, through Traefik (valid certificate)."
  type        = string
  default     = "wss://bruxelles.anneraud.fr/api/current"
}

variable "truenas_api_key" {
  description = "API key of the TrueNAS user opentofu (Apps privilege)."
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
  default     = "../../vault/archive/opentofu.tfstate"
}

variable "archive_client_id" {
  description = "Client id of Paperless's Zitadel application."
  type        = string
}

variable "archive_client_secret" {
  description = "Client secret of Paperless's Zitadel application."
  type        = string
  sensitive   = true
}

variable "archive_environment" {
  description = "Other environment variables of the Paperless container, kept next to the login's (archive.auto.tfvars)."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "import_existing_app" {
  description = "Import the existing paperless-ngx app (off only in tests, which mock TrueNAS)."
  type        = bool
  default     = true
}
