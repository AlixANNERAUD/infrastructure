# The organization's own policies: the instance defaults stay untouched, so
# a mistake here never locks out the ZITADEL organization's admin

resource "zitadel_login_policy" "organization" {
  org_id = zitadel_org.organization.id

  user_login                    = true
  allow_register                = false
  allow_external_idp            = false
  force_mfa                     = false
  force_mfa_local_only          = false
  passwordless_type             = "PASSWORDLESS_TYPE_ALLOWED"
  second_factors                = ["SECOND_FACTOR_TYPE_OTP", "SECOND_FACTOR_TYPE_U2F"]
  multi_factors                 = ["MULTI_FACTOR_TYPE_U2F_WITH_VERIFICATION"]
  hide_password_reset           = false
  ignore_unknown_usernames      = true
  default_redirect_uri          = ""
  password_check_lifetime       = "240h0m0s"
  external_login_check_lifetime = "240h0m0s"
  second_factor_check_lifetime  = "18h0m0s"
  multi_factor_check_lifetime   = "18h0m0s"
  mfa_init_skip_lifetime        = "720h0m0s"
}

# Length only: character classes make passwords harder to remember, not stronger
resource "zitadel_password_complexity_policy" "organization" {
  org_id = zitadel_org.organization.id

  min_length    = 12
  has_lowercase = false
  has_uppercase = false
  has_number    = false
  has_symbol    = false
}

resource "zitadel_lockout_policy" "organization" {
  org_id = zitadel_org.organization.id

  max_password_attempts = 10
}

# The organization's domain counts as verified without a DNS record: the
# instance and the organization belong to the same owner
resource "zitadel_domain_policy" "organization" {
  org_id = zitadel_org.organization.id

  user_login_must_be_domain                   = true
  validate_org_domains                        = false
  smtp_sender_address_matches_instance_domain = false
}
