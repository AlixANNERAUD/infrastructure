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

  # Open WebUI (assistant.anneraud.fr), a TrueNAS app: services/assistant
  # gives its variables. It reads no roles from Zitadel's map claim
  open_webui = {
    project        = "Assistant"
    authentication = "client_secret"
    redirect_uris  = ["https://assistant.anneraud.fr/oauth/oidc/callback"]
  }

  # Mealie (recettes.anneraud.fr), a TrueNAS app: services/recettes gives its
  # variables. recettes-admin makes a Mealie admin, at every login
  mealie = {
    project        = "Recettes"
    authentication = "client_secret"
    roles          = [{ key = "recettes-admin", display_name = "Recettes administrator" }]
    redirect_uris  = ["https://recettes.anneraud.fr/login"]
  }

  # Gitea (git.anneraud.fr), a TrueNAS app: services/git gives its
  # authentication source, named Zitadel (part of the callback)
  gitea = {
    project        = "Git"
    authentication = "client_secret"
    redirect_uris  = ["https://git.anneraud.fr/user/oauth2/Zitadel/callback"]
  }
}
