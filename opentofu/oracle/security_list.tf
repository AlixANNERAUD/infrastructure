# The tenancy's only VCN and subnet hold Luxembourg; its security list is the
# subnet's default one, whose rules OpenTofu now owns entirely: anything
# added in the console is removed on the next apply
data "oci_core_vcns" "all" {
  compartment_id = var.tenancy_ocid
}

locals {
  vcn = one(data.oci_core_vcns.all.virtual_networks)

  protocol_numbers = { tcp = "6", udp = "17" }

  # Every public port, from IPv4 and IPv6 alike
  port_rules = flatten([
    for entry in var.public_ports : [
      for source in ["0.0.0.0/0", "::/0"] : {
        protocol    = local.protocol_numbers[entry.protocol]
        source      = source
        first_port  = entry.port
        last_port   = coalesce(entry.last_port, entry.port)
        description = "${entry.service}, IPv${source == "::/0" ? 6 : 4}"
      }
    ]
  ])

  # ICMP that the network needs: path MTU discovery (fragmentation needed,
  # packet too big), errors from inside the VCN, and IPv6 ping
  icmp_rules = concat(
    [{ protocol = "1", source = "0.0.0.0/0", type = 3, code = 4, description = "Path MTU discovery, IPv4" }],
    [for cidr in local.vcn.cidr_blocks : { protocol = "1", source = cidr, type = 3, code = null, description = "Unreachable messages from the VCN" }],
    [
      { protocol = "58", source = "::/0", type = 2, code = null, description = "Path MTU discovery, IPv6" },
      { protocol = "58", source = "::/0", type = 128, code = null, description = "Ping, IPv6" },
    ],
  )
}

resource "oci_core_default_security_list" "luxembourg" {
  manage_default_resource_id = local.vcn.default_security_list_id

  dynamic "ingress_security_rules" {
    for_each = local.port_rules
    iterator = rule

    content {
      protocol    = rule.value.protocol
      source      = rule.value.source
      source_type = "CIDR_BLOCK"
      stateless   = false
      description = rule.value.description

      dynamic "tcp_options" {
        for_each = rule.value.protocol == "6" ? [rule.value] : []

        content {
          min = tcp_options.value.first_port
          max = tcp_options.value.last_port
        }
      }

      dynamic "udp_options" {
        for_each = rule.value.protocol == "17" ? [rule.value] : []

        content {
          min = udp_options.value.first_port
          max = udp_options.value.last_port
        }
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = local.icmp_rules
    iterator = rule

    content {
      protocol    = rule.value.protocol
      source      = rule.value.source
      source_type = "CIDR_BLOCK"
      stateless   = false
      description = rule.value.description

      icmp_options {
        type = rule.value.type
        code = rule.value.code
      }
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    stateless        = false
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "::/0"
    destination_type = "CIDR_BLOCK"
    stateless        = false
  }

  lifecycle {
    precondition {
      condition     = length(data.oci_core_vcns.all.virtual_networks) == 1
      error_message = "The tenancy should hold exactly one VCN, Luxembourg's."
    }
  }
}
