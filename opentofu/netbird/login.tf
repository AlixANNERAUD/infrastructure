# Login through Zitadel, next to NetBird's local accounts: the application
# comes from opentofu/zitadel (applications.auto.tfvars, netbird)
resource "netbird_identity_provider" "zitadel" {
  name          = "Zitadel"
  type          = "zitadel"
  issuer        = "https://authentification.anneraud.fr"
  client_id     = var.zitadel_client_id
  client_secret = var.zitadel_client_secret
}
