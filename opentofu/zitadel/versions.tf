terraform {
  # Variables in the backend and encryption blocks need OpenTofu 1.8
  required_version = ">= 1.8"

  required_providers {
    zitadel = {
      source  = "zitadel/zitadel"
      version = "= 3.8.7"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }

  # The state holds client secrets: it lives in the private vault repository
  backend "local" {
    path = var.state_path
  }
}
