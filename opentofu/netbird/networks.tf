# Each host routes its own LAN address, so peers reach the services it
# publishes there (Traefik) through the VPN; the policies (policies.tf) open
# each of them to every peer
locals {
  networks = {
    bruxelles  = { name = "Bruxelles", resource = "Bruxelles loopback", address = "192.168.0.21/32" }
    luxembourg = { name = "Luxembourg", resource = "Luxembourg 2", address = "192.168.2.16/32" }
    paris      = { name = "Paris", resource = "Paris loopback", address = "192.168.1.61/32" }
  }
}

resource "netbird_network" "host" {
  for_each = local.networks

  name        = each.value.name
  description = ""
}

resource "netbird_network_resource" "host" {
  for_each = local.networks

  network_id  = netbird_network.host[each.key].id
  name        = each.value.resource
  address     = each.value.address
  description = ""
  enabled     = true

  # The provider requires a group, but these resources have none: the
  # policies (policies.tf) target each of them directly
  groups = [netbird_group.infrastructure.id]
  lifecycle {
    ignore_changes = [groups]
  }
}

resource "netbird_network_router" "host" {
  for_each = local.networks

  network_id = netbird_network.host[each.key].id
  peer       = data.netbird_peer.peer[each.key].id
  masquerade = true
  metric     = 9999
  enabled    = true
}
