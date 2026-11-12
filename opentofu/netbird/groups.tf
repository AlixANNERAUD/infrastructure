# Peers join groups through their user's auto groups and the setup keys, not
# through this configuration: OpenTofu keeps the groups, never their members
locals {
  # The hosts routing to their own LAN address (networks.tf) and the exit nodes
  peers = toset(["bruxelles", "luxembourg", "paris", "pristina"])
}

data "netbird_peer" "peer" {
  for_each = local.peers

  name = each.value
}

# Built in: every peer
data "netbird_group" "all" {
  name = "All"
}

resource "netbird_group" "anneraud" {
  name = "ANNERAUD"

  lifecycle {
    ignore_changes = [peers, resources]
  }
}

resource "netbird_group" "infrastructure" {
  name = "Infrastructure"

  lifecycle {
    ignore_changes = [peers, resources]
  }
}

resource "netbird_group" "alix" {
  name = "Alix ANNERAUD"

  lifecycle {
    ignore_changes = [peers, resources]
  }
}

resource "netbird_group" "client" {
  name = "Client"

  lifecycle {
    ignore_changes = [peers, resources]
  }
}

# Empty
resource "netbird_group" "paris" {
  name = "paris"

  lifecycle {
    ignore_changes = [peers, resources]
  }
}
