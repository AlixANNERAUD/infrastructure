# The setup key of the exit node through Proton VPN, written for the owner by
# services/maillage/configuration.yml
output "sortie_setup_key" {
  description = "Setup key the services/sortie peer joins with."
  value       = netbird_setup_key.sortie.key
  sensitive   = true
}
