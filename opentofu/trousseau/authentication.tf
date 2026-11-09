# Login through Zitadel, from the web interface (/ui) and from the CLI
# (bao login -method=oidc callbackmode=direct): both come back to OpenBao's
# own address, so Zitadel needs no plain-HTTP localhost redirect
locals {
  oidc_enabled = var.oidc_client_id != ""
  oidc_path    = "oidc"
}

resource "vault_jwt_auth_backend" "zitadel" {
  count = local.oidc_enabled ? 1 : 0

  path               = local.oidc_path
  type               = "oidc"
  description        = "Zitadel (authentification.anneraud.fr)"
  oidc_discovery_url = var.zitadel_issuer
  oidc_client_id     = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  default_role       = "administration"

  tune {
    # Offered on the web interface's login page
    listing_visibility = "unauth"
    default_lease_ttl  = "1h"
    max_lease_ttl      = "8h"
  }
}

# OpenBao cannot match Zitadel's role claim (a map of roles): the
# administrator is the account with this email, which OpenBao reads from
# Zitadel's userinfo endpoint
resource "vault_jwt_auth_backend_role" "administration" {
  count = local.oidc_enabled ? 1 : 0

  backend      = vault_jwt_auth_backend.zitadel[0].path
  role_name    = "administration"
  role_type    = "oidc"
  user_claim   = "email"
  oidc_scopes  = ["email"]
  bound_claims = { email = var.administrator_email }
  allowed_redirect_uris = [
    "${var.address}/ui/vault/auth/${local.oidc_path}/oidc/callback",
    "${var.address}/v1/auth/${local.oidc_path}/oidc/callback",
  ]
  token_policies = [vault_policy.administration.name]
  token_ttl      = 3600
  token_max_ttl  = 8 * 3600
}
