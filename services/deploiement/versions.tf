terraform {
  required_version = ">= 1.9"

  required_providers {
    semaphoreui = {
      source  = "semaphoreui/semaphore"
      version = "= 0.3.10"
    }
  }

  # The state holds the SSH key and the vault password Semaphore deploys with:
  # it lives in the private vault repository
  backend "local" {
    path = var.state_path
  }
}
