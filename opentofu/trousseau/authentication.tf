# Login through Zitadel, from the web interface (/ui) and from the command
# line (bao login -method=oidc role=terminal callbackmode=direct): both come
# back to OpenBao's own address, so Zitadel needs no plain-HTTP localhost
# redirect
locals {
  oidc_enabled = var.oidc_client_id != ""
  oidc_path    = "oidc"

  # bao login always writes the port in its redirect (https://host:443/v1/...),
  # and OpenBao and Zitadel compare redirects as plain strings
  address = regex("^(?P<scheme>https?)://(?P<host>[^/:]+)(?::(?P<port>[0-9]+))?$", var.address)
  address_with_port = format(
    "%s://%s:%s", local.address.scheme, local.address.host,
    coalesce(local.address.port, local.address.scheme == "https" ? "443" : "80"),
  )
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

# The administrator is one Zitadel account, named by its user id (the sub
# claim): an email could be claimed by another account of the organization,
# and OpenBao cannot match Zitadel's role claim (a map of roles).
#
# The web interface's role: the browser comes back to the interface, which
# hands the code over
resource "vault_jwt_auth_backend_role" "administration" {
  count = local.oidc_enabled ? 1 : 0

  backend       = vault_jwt_auth_backend.zitadel[0].path
  role_name     = "administration"
  role_type     = "oidc"
  user_claim    = "sub"
  bound_subject = var.administrator_user_id
  allowed_redirect_uris = [
    "${var.address}/ui/vault/auth/${local.oidc_path}/oidc/callback",
  ]
  token_policies = [vault_policy.administration.name]
  token_ttl      = 3600
  token_max_ttl  = 8 * 3600
}

# The command line's role: the browser comes back to OpenBao itself
# (callback_mode direct), which asks for a confirmation, while bao login
# polls for its token. The provider's role resource has no callback_mode
# (OpenBao only), hence the generic endpoint
resource "vault_generic_endpoint" "terminal" {
  count = local.oidc_enabled ? 1 : 0

  path                 = "auth/${vault_jwt_auth_backend.zitadel[0].path}/role/terminal"
  ignore_absent_fields = true
  data_json = jsonencode({
    role_type     = "oidc"
    callback_mode = "direct"
    user_claim    = "sub"
    bound_subject = var.administrator_user_id
    allowed_redirect_uris = [
      "${local.address_with_port}/v1/auth/${local.oidc_path}/oidc/callback",
    ]
    token_policies = [vault_policy.administration.name]
    token_ttl      = 3600
    token_max_ttl  = 8 * 3600
  })
}
