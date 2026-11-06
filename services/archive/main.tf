# Paperless (archive.anneraud.fr) is a TrueNAS app: OpenTofu only manages its
# login through Zitadel, in the app's extra environment variables. Everything
# else in the app (storage, version, resources) stays managed in TrueNAS.
# The app predates OpenTofu: imported, then this block does nothing. Tests turn
# it off, since OpenTofu cannot import with a mocked provider
import {
  for_each = var.import_existing_app ? toset(["paperless-ngx"]) : toset([])
  to       = truenas_app.paperless
  id       = each.value
}

locals {
  # django-allauth's OpenID Connect provider; the secret goes in the token
  # request's body, as the Zitadel application expects (client_secret_post)
  login_providers = {
    openid_connect = {
      OAUTH_PKCE_ENABLED = true
      APPS = [{
        provider_id = "zitadel"
        name        = "Zitadel"
        client_id   = var.archive_client_id
        secret      = var.archive_client_secret
        settings = {
          server_url        = "https://authentification.anneraud.fr"
          token_auth_method = "client_secret_post"
        }
      }]
    }
  }

  environment = concat(var.archive_environment, [
    { name = "PAPERLESS_APPS", value = "allauth.socialaccount.providers.openid_connect" },
    { name = "PAPERLESS_SOCIALACCOUNT_PROVIDERS", value = jsonencode(local.login_providers) },
  ])
}

resource "truenas_app" "paperless" {
  name        = "paperless-ngx"
  catalog_app = "paperless-ngx"
  train       = "community"

  # Only these keys are managed; the provider leaves the app's other values alone.
  # The list replaces the app's whole list: other variables go in archive.auto.tfvars
  values = jsonencode({
    paperless = {
      additional_envs = [for variable in local.environment : {
        container = "paperless"
        name      = variable.name
        value     = variable.value
      }]
    }
  })

  # The app holds the documents: no code change may delete it
  lifecycle {
    prevent_destroy = true
  }
}
