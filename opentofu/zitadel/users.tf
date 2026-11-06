# People of the organization, listed in the vault (the repository is public).
# Without temporary_password, Zitadel emails an invitation to choose one.

locals {
  temporary_password_users = { for name, user in var.users : name => user if user.temporary_password }

  # One grant per user and project
  grants = merge([
    for name, user in var.users : {
      for project, roles in user.roles : "${name}/${project}" => {
        user    = name
        project = project
        roles   = roles
      }
    }
  ]...)

  # Accounts on services that predate Zitadel (Nextcloud ids are display names)
  service_accounts = merge([
    for name, user in var.users : {
      for service, account in user.service_accounts : "${name}/${service}" => {
        user    = name
        service = service
        account = account
      }
    }
  ]...)
}

resource "random_password" "temporary" {
  for_each = local.temporary_password_users

  length  = 24
  special = false
}

resource "zitadel_human_user" "user" {
  for_each = var.users

  org_id     = zitadel_org.organization.id
  user_name  = each.key
  first_name = each.value.first_name
  last_name  = each.value.last_name
  email      = each.value.email

  # Someone with a temporary password gets it from the owner: nothing is
  # emailed. The others get Zitadel's invitation at their address.
  initial_password             = each.value.temporary_password ? random_password.temporary[each.key].result : null
  initial_skip_password_change = false
  is_email_verified            = each.value.temporary_password

  # Only used at creation: changing them later must not recreate the user
  lifecycle {
    ignore_changes = [initial_password, is_email_verified]
  }
}

resource "zitadel_user_grant" "grant" {
  for_each = local.grants

  org_id     = zitadel_org.organization.id
  user_id    = zitadel_human_user.user[each.value.user].id
  project_id = zitadel_project.project[each.value.project].id
  role_keys  = each.value.roles

  depends_on = [zitadel_project_role.role]
}

resource "zitadel_org_member" "owner" {
  for_each = { for name, user in var.users : name => user if user.owner }

  org_id  = zitadel_org.organization.id
  user_id = zitadel_human_user.user[each.key].id
  roles   = ["ORG_OWNER"]
}

resource "zitadel_user_metadata" "service_account" {
  for_each = local.service_accounts

  org_id  = zitadel_org.organization.id
  user_id = zitadel_human_user.user[each.value.user].id
  key     = "${each.value.service}_account"
  value   = each.value.account
}
