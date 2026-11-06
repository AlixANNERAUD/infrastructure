# Zitadel's emails (invitations, password resets) go through SMTP2GO, whose
# DKIM signature on anneraud.fr satisfies the domain's DMARC policy. SMTP is
# instance-wide in Zitadel: the only instance setting managed here.
resource "zitadel_email_provider_smtp" "smtp" {
  count = var.smtp_host == "" ? 0 : 1

  host           = var.smtp_host
  user           = var.smtp_user
  password       = var.smtp_password
  tls            = true
  sender_address = "authentification@anneraud.fr"
  sender_name    = "Anneraud"
  set_active     = true
}
