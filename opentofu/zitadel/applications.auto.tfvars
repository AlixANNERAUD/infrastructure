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

  # NetBird (netbird.anneraud.fr): its embedded identity provider (Dex) logs
  # in through Zitadel as a confidential client; services/maillage/configuration.yml
  # passes the client to opentofu/netbird
  netbird = {
    project          = "NetBird"
    authentication   = "client_secret"
    redirect_uris    = ["https://netbird.anneraud.fr/oauth2/callback"]
    post_logout_uris = ["https://netbird.anneraud.fr/oauth2/logout/callback"]
  }

  # Home Assistant (maison.anneraud.fr), through the OpenID Connect integration
  # installed by services/maison: a public client. Home Assistant creates an
  # account for anyone who logs in, so only people with the maison role can
  maison = {
    project       = "Maison"
    roles         = [{ key = "maison", display_name = "Home Assistant" }]
    require_role  = true
    redirect_uris = ["https://maison.anneraud.fr/auth/oidc/callback"]
  }

  # recto (impression.anneraud.fr), services/impression: a public client.
  # Only people with the impression role can log in; impression-admin makes
  # an administrator, read from the roles claim of the ID token
  impression = {
    project = "Impression"
    roles = [
      { key = "impression", display_name = "Impression" },
      { key = "impression-admin", display_name = "Impression administrator" },
    ]
    require_role         = true
    userinfo_in_id_token = true
    redirect_uris        = ["https://impression.anneraud.fr/auth/callback"]
    post_logout_uris     = ["https://impression.anneraud.fr/auth/signed-out"]
  }

  # Semaphore (deploiement.anneraud.fr): a confidential client, which reads the
  # email from the ID token ("claim 'email' missing" otherwise)
  deploiement = {
    project              = "Deploiement"
    authentication       = "client_secret"
    userinfo_in_id_token = true
    redirect_uris        = ["https://deploiement.anneraud.fr/api/auth/oidc/zitadel/redirect"]
  }
}
