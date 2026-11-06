# Paperless's environment as the TrueNAS app receives it, without a TrueNAS
mock_provider "truenas" {}

variables {
  truenas_api_key       = "test-api-key"
  state_passphrase      = "test-state-passphrase"
  state_path            = "test.tfstate"
  archive_client_id     = "client-id"
  archive_client_secret = "client-secret"
  archive_environment   = [{ name = "PAPERLESS_URL", value = "https://archive.anneraud.fr" }]
  import_existing_app   = false
}

run "login_environment" {
  command = plan

  assert {
    condition     = truenas_app.paperless.name == "paperless-ngx"
    error_message = "The managed app is not paperless-ngx."
  }

  assert {
    condition     = [for variable in jsondecode(truenas_app.paperless.values).paperless.additional_envs : variable.name] == ["PAPERLESS_URL", "PAPERLESS_APPS", "PAPERLESS_SOCIALACCOUNT_PROVIDERS"]
    error_message = "The environment does not keep the other variables before the login's."
  }

  assert {
    condition     = alltrue([for variable in jsondecode(truenas_app.paperless.values).paperless.additional_envs : variable.container == "paperless"])
    error_message = "A variable does not go to the paperless container."
  }

  assert {
    condition     = jsondecode(truenas_app.paperless.values).paperless.additional_envs[1].value == "allauth.socialaccount.providers.openid_connect"
    error_message = "PAPERLESS_APPS does not enable allauth's OpenID Connect provider."
  }

  assert {
    condition = (
      jsondecode(jsondecode(truenas_app.paperless.values).paperless.additional_envs[2].value).openid_connect.APPS[0].provider_id == "zitadel"
      && jsondecode(jsondecode(truenas_app.paperless.values).paperless.additional_envs[2].value).openid_connect.APPS[0].client_id == "client-id"
      && jsondecode(jsondecode(truenas_app.paperless.values).paperless.additional_envs[2].value).openid_connect.APPS[0].secret == "client-secret"
      && jsondecode(jsondecode(truenas_app.paperless.values).paperless.additional_envs[2].value).openid_connect.APPS[0].settings.server_url == "https://authentification.anneraud.fr"
      && jsondecode(jsondecode(truenas_app.paperless.values).paperless.additional_envs[2].value).openid_connect.APPS[0].settings.token_auth_method == "client_secret_post"
      && jsondecode(jsondecode(truenas_app.paperless.values).paperless.additional_envs[2].value).openid_connect.OAUTH_PKCE_ENABLED == true
    )
    error_message = "PAPERLESS_SOCIALACCOUNT_PROVIDERS does not describe the Zitadel login."
  }
}
