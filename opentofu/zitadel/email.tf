# Zitadel's emails (invitations, password resets) go through SMTP2GO, whose
# DKIM signature on anneraud.fr satisfies the domain's DMARC policy. SMTP is
# instance-wide in Zitadel: the only instance setting managed here.
locals {
  smtp = {
    host           = var.smtp_host
    user           = var.smtp_user
    tls            = true
    sender_address = "authentification@anneraud.fr"
    sender_name    = "Anneraud"
  }
}

# Zitadel cannot change an SMTP provider in place: the update carries the
# password, which its read model fails to apply (zitadel/zitadel#12553), so it
# keeps sending with the old settings and every email fails. Any change
# therefore replaces the provider, which this hash of all settings triggers.
resource "terraform_data" "smtp" {
  count = var.smtp_host == "" ? 0 : 1

  input = sha256(jsonencode(merge(local.smtp, { password = var.smtp_password })))
}

resource "zitadel_email_provider_smtp" "smtp" {
  count = var.smtp_host == "" ? 0 : 1

  host           = local.smtp.host
  user           = local.smtp.user
  password       = var.smtp_password
  tls            = local.smtp.tls
  sender_address = local.smtp.sender_address
  sender_name    = local.smtp.sender_name
  set_active     = true

  lifecycle {
    # The new provider is activated before the old one is removed, so an
    # active provider is never deleted
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.smtp[count.index]]
  }
}
