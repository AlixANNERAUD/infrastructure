# Claims filled from user metadata, for services whose accounts predate
# Zitadel (Nextcloud's user ids are display names). Zitadel stores metadata
# base64-encoded under urn:zitadel:iam:user:metadata, which these services
# cannot read: an action (Actions v1, run by Zitadel itself) copies the value
# into a plain claim, only for the application that asks for it.

locals {
  # Application name => metadata key, for applications with an account_claim
  account_claim_applications = {
    for name, application in var.applications : name => application.account_claim
    if application.account_claim != null
  }
}

resource "zitadel_action" "account_claims" {
  count = length(local.account_claim_applications) > 0 ? 1 : 0

  org_id = zitadel_org.organization.id
  # The script's function has the action's name
  name = "accountClaims"
  script = templatefile("${path.module}/actions/account_claims.js.tftpl", {
    # Client id => metadata key; client ids are only known once applied
    account_claims = jsonencode({
      for name, key in local.account_claim_applications : zitadel_application_oidc.application[name].client_id => key
    })
  })
  timeout = "10s"
  # A failure leaves the claim out (the service then refuses the login) instead
  # of failing the tokens of every application
  allowed_to_fail = true
}

# Before userinfo creation: also runs for the ID token, which takes the claims
# set here whatever the scopes. This resource owns the trigger's whole list.
resource "zitadel_trigger_actions" "userinfo" {
  count = length(local.account_claim_applications) > 0 ? 1 : 0

  org_id       = zitadel_org.organization.id
  flow_type    = "FLOW_TYPE_CUSTOMISE_TOKEN"
  trigger_type = "TRIGGER_TYPE_PRE_USERINFO_CREATION"
  action_ids   = [zitadel_action.account_claims[0].id]
}
