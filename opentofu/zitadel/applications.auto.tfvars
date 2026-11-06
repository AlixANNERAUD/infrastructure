# One entry per OIDC application. authentication: pkce (default),
# client_secret (HTTP Basic) or client_secret_post (secret in the request
# body); configured_in: where the owner pastes the result, for services
# managed outside this repository.
applications = {
  grafana = {
    project          = "Vigie"
    roles            = [{ key = "vigie-admin", display_name = "Vigie administrator" }]
    redirect_uris    = ["https://vigie.anneraud.fr/login/generic_oauth"]
    post_logout_uris = ["https://vigie.anneraud.fr/login"]
  }

  # Better Auth sends the client secret in the request body
  mcphub = {
    project          = "MCPHub"
    authentication   = "client_secret_post"
    redirect_uris    = ["https://mcphub.anneraud.fr/api/auth/better/oauth2/callback/oidc"]
    post_logout_uris = ["https://mcphub.anneraud.fr/"]
  }

  # Paperless (archive.anneraud.fr), a TrueNAS app: services/archive passes
  # the client to it. django-allauth sends the secret in the request body
  paperless = {
    project        = "Archive"
    authentication = "client_secret_post"
    redirect_uris  = ["https://archive.anneraud.fr/accounts/oidc/zitadel/login/callback/"]
  }

  # Semaphore (deploiement.anneraud.fr): a confidential client
  deploiement = {
    project        = "Deploiement"
    authentication = "client_secret"
    redirect_uris  = ["https://deploiement.anneraud.fr/api/auth/oidc/zitadel/redirect"]
  }

  # Netbird (netbird.anneraud.fr, services/vpn): an external connector of
  # Netbird's embedded identity provider, added in its dashboard next to the
  # local logins, which stay (see the readme's "Netbird login through
  # Zitadel"). The callback is the embedded provider's, for every connector
  netbird = {
    project          = "VPN"
    authentication   = "client_secret"
    redirect_uris    = ["https://netbird.anneraud.fr/oauth2/callback"]
    post_logout_uris = ["https://netbird.anneraud.fr/oauth2/logout/callback"]
    configured_in    = "Netbird → Settings → Identity Providers → Add Identity Provider (type Zitadel)"
  }
}
