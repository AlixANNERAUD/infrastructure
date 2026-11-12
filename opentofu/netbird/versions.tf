terraform {
  # Variables in the backend and encryption blocks need OpenTofu 1.8
  required_version = ">= 1.8"

  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
      version = "= 0.0.11"
    }
  }

  # The state holds the identity provider's client secret: it lives in the
  # private vault repository
  backend "local" {
    path = var.state_path
  }
}
