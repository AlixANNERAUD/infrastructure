# The exit node through Proton VPN (services/sortie). Reusable so that the
# peer can join again if its state is lost; services/maillage/configuration.yml
# writes it to ~/.config/infrastructure/netbird/sortie.setup-key, for the vault
resource "netbird_setup_key" "sortie" {
  name                   = "sortie"
  type                   = "reusable"
  auto_groups            = [netbird_group.sortie.id]
  usage_limit            = 0
  ephemeral              = false
  allow_extra_dns_labels = false
  revoked                = false
  expiry_seconds         = 0
}

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
