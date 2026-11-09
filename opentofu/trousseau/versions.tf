terraform {
  # Variables in the backend and encryption blocks need OpenTofu 1.8
  required_version = ">= 1.8"

  required_providers {
    # HashiCorp's provider, which OpenBao's API is compatible with
    vault = {
      source  = "hashicorp/vault"
      version = "= 5.13.0"
    }
  }

  # The state holds the Zitadel client secret: it lives in the private vault
  # repository, encrypted (encryption.tf)
  backend "local" {
    path = var.state_path
  }
}
