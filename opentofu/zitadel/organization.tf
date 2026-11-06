# The organization everything else belongs to. The service account lives in
# the ZITADEL organization, which stays the instance's break-glass admin.
resource "zitadel_org" "organization" {
  name       = var.organization_name
  is_default = true
}

# Logins read <user>@<domain>; the domain policy below skips the DNS proof
resource "zitadel_domain" "organization" {
  org_id     = zitadel_org.organization.id
  name       = var.organization_domain
  is_primary = true

  depends_on = [zitadel_domain_policy.organization]
}
