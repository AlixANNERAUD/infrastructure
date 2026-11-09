# The AppRole created at OpenBao's first start (services/trousseau/config.hcl.j2)
provider "vault" {
  address = var.address
  # The AppRole token has the administration policy; no child token needed
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = "deploiement"
      secret_id = var.automation_secret_id
    }
  }
}
