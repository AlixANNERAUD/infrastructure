# The account's settings, as set in the dashboard before OpenTofu took over
resource "netbird_account_settings" "account" {
  dns_domain                             = "local.anneraud.fr"
  network_range                          = "100.64.0.0/16"
  auto_update_version                    = "disabled"
  groups_propagation_enabled             = true
  jwt_groups_enabled                     = false
  jwt_groups_claim_name                  = ""
  jwt_allow_groups                       = []
  lazy_connection_enabled                = true
  network_traffic_logs_enabled           = false
  network_traffic_packet_counter_enabled = false
  peer_expose_enabled                    = false
  peer_inactivity_expiration_enabled     = false
  peer_inactivity_expiration             = 600
  # A device logs in again every 31 days
  peer_login_expiration_enabled       = true
  peer_login_expiration               = 2678400
  regular_users_view_blocked          = true
  routing_peer_dns_resolution_enabled = true
  # New users wait for an administrator's approval
  user_approval_required = true
}
