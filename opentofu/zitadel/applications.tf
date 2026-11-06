# Projects, roles and applications belong to the organization (organization.tf)
locals {
  authentication_methods = {
    pkce               = "OIDC_AUTH_METHOD_TYPE_NONE"
    client_secret      = "OIDC_AUTH_METHOD_TYPE_BASIC"
    client_secret_post = "OIDC_AUTH_METHOD_TYPE_POST"
  }

  projects = toset([for application in values(var.applications) : application.project])

  # Roles are declared per application but belong to the project
  roles = merge([
    for application in values(var.applications) : {
      for role in application.roles : "${application.project}/${role.key}" => {
        project      = application.project
        key          = role.key
        display_name = role.display_name
      }
    }
  ]...)
}

resource "zitadel_project" "project" {
  for_each = local.projects

  name   = each.value
  org_id = zitadel_org.organization.id
}

resource "zitadel_project_role" "role" {
  for_each = local.roles

  org_id       = zitadel_org.organization.id
  project_id   = zitadel_project.project[each.value.project].id
  role_key     = each.value.key
  display_name = each.value.display_name
}

resource "zitadel_application_oidc" "application" {
  for_each = var.applications

  org_id     = zitadel_org.organization.id
  project_id = zitadel_project.project[each.value.project].id
  name       = each.key

  app_type                  = "OIDC_APP_TYPE_WEB"
  response_types            = ["OIDC_RESPONSE_TYPE_CODE"]
  grant_types               = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
  auth_method_type          = local.authentication_methods[each.value.authentication]
  redirect_uris             = each.value.redirect_uris
  post_logout_redirect_uris = each.value.post_logout_uris
  # Zitadel only accepts plain-HTTP redirects in development mode
  dev_mode = alltrue([for uri in each.value.redirect_uris : startswith(uri, "http://localhost")])
}
