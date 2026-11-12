# Exit nodes: a peer of the given groups can send all its traffic out through
# one of them. Pristina also routes its own LAN address
locals {
  exit_nodes = {
    luxembourg = { network_id = "Exit Node (luxembourg) 2", groups = [netbird_group.anneraud.id, netbird_group.client.id] }
    pristina   = { network_id = "Exit Node (pristina)", groups = [netbird_group.anneraud.id, netbird_group.client.id] }
    bruxelles  = { network_id = "Exit Node (bruxelles)", groups = [netbird_group.anneraud.id] }
  }
}

resource "netbird_route" "exit_node" {
  for_each = local.exit_nodes

  network_id  = each.value.network_id
  network     = "0.0.0.0/0"
  peer        = data.netbird_peer.peer[each.key].id
  groups      = each.value.groups
  masquerade  = true
  metric      = 9999
  enabled     = true
  keep_route  = false
  description = ""
}

resource "netbird_route" "pristina_loopback" {
  network_id  = "Pristina loopback"
  network     = "192.168.0.22/32"
  peer        = data.netbird_peer.peer["pristina"].id
  groups      = [netbird_group.anneraud.id]
  masquerade  = true
  metric      = 9999
  enabled     = true
  keep_route  = false
  description = ""
}
