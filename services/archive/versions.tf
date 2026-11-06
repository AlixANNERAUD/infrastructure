terraform {
  # Variables in the backend and encryption blocks need OpenTofu 1.8
  required_version = ">= 1.8"

  required_providers {
    truenas = {
      source  = "truenas/truenas"
      version = "= 1.8.0"
    }
  }

  # The state holds the app's client secret: it lives in the private vault repository
  backend "local" {
    path = var.state_path
  }
}
