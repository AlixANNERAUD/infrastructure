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

  # Nuage (nuage.anneraud.fr), Nextcloud as a TrueNAS app: services/nuage
  # configures its user_oidc app. Its accounts predate Zitadel: the user id
  # comes from the nextcloud_account claim (user metadata, see actions.tf).
  # Both redirects: Nextcloud adds index.php without pretty URLs
  nextcloud = {
    project        = "Nuage"
    authentication = "client_secret_post"
    account_claim  = "nextcloud_account"
    redirect_uris = [
      "https://nuage.anneraud.fr/apps/user_oidc/code",
      "https://nuage.anneraud.fr/index.php/apps/user_oidc/code",
    ]
    post_logout_uris = ["https://nuage.anneraud.fr/"]
  }
}
