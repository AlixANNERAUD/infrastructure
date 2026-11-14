provider "semaphoreui" {
  api_base_url = "${var.semaphore_url}/api"
  api_token    = var.semaphore_token
}
