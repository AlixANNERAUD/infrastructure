# GitHub Actions runners of the Xila project join as ephemeral peers
resource "netbird_setup_key" "github_xila" {
  name                   = "github_xila"
  type                   = "reusable"
  auto_groups            = [netbird_group.anneraud.id, netbird_group.alix.id, netbird_group.infrastructure.id]
  usage_limit            = 0
  ephemeral              = true
  allow_extra_dns_labels = false
  revoked                = false
  # Never expires. The API reports no expiry_seconds, so the first apply
  # only records it in the state: it changes nothing on the key
  expiry_seconds = 0
}
