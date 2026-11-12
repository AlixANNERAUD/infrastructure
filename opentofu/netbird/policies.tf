# Access between peers. The default policy lets every peer reach every other
# one; the others open each host's LAN address (networks.tf)
resource "netbird_policy" "default" {
  name        = "Default"
  description = "This is a default rule that allows connections between all the resources"
  enabled     = true

  rule {
    name          = "Default"
    description   = "This is a default rule that allows connections between all the resources"
    action        = "accept"
    protocol      = "all"
    bidirectional = true
    enabled       = true
    sources       = [data.netbird_group.all.id]
    destinations  = [data.netbird_group.all.id]
  }
}

resource "netbird_policy" "bruxelles_loopback" {
  name    = "Bruxelles loopback Policy"
  enabled = true

  source_posture_checks = []

  rule {
    name          = "Bruxelles loopback Policy"
    action        = "accept"
    protocol      = "all"
    bidirectional = false
    enabled       = true
    sources       = [data.netbird_group.all.id]
    destinations  = [data.netbird_group.all.id]
  }
}

resource "netbird_policy" "host" {
  for_each = {
    bruxelles  = { name = "Bruxelles Access", description = null }
    luxembourg = { name = "Luxembourg 2 Access", description = "Luxembourg" }
    paris      = { name = "Paris loopback Access", description = null }
  }

  name        = each.value.name
  description = each.value.description
  enabled     = true

  source_posture_checks = []

  rule {
    name          = each.value.name
    description   = each.value.description
    action        = "accept"
    protocol      = "all"
    bidirectional = false
    enabled       = true
    sources       = [data.netbird_group.all.id]
    destination_resource = {
      id   = netbird_network_resource.host[each.key].id
      type = "host"
    }
  }
}

# Left over: its destination resource is gone from Luxembourg's network,
# which now has only "Luxembourg 2"
resource "netbird_policy" "luxembourg_former" {
  name    = "Luxembourg Access"
  enabled = true

  source_posture_checks = []

  rule {
    name          = "Luxembourg Access"
    action        = "accept"
    protocol      = "all"
    bidirectional = false
    enabled       = true
    sources       = [data.netbird_group.all.id]
    destination_resource = {
      id   = "da9gprg0rep0008cmg20"
      type = "host"
    }
  }
}

# Left over: from paris to a subnet resource that no network holds anymore
resource "netbird_policy" "sfr" {
  name    = "SFR Access"
  enabled = true

  source_posture_checks = []

  rule {
    name          = "SFR Access"
    action        = "accept"
    protocol      = "all"
    bidirectional = false
    enabled       = true
    source_resource = {
      id   = data.netbird_peer.peer["paris"].id
      type = "peer"
    }
    destination_resource = {
      id   = "d9n1vf00rep000ci0vl0"
      type = "subnet"
    }
  }
}
