mock_provider "oci" {
  mock_data "oci_core_vcns" {
    defaults = {
      # Every attribute of a listed VCN must be given
      virtual_networks = [{
        id                               = "ocid1.vcn.oc1..test"
        compartment_id                   = "ocid1.tenancy.oc1..test"
        display_name                     = "vcn"
        dns_label                        = "vcn"
        vcn_domain_name                  = "vcn.oraclevcn.com"
        state                            = "AVAILABLE"
        time_created                     = "2022-01-20T13:24:00Z"
        cidr_block                       = "10.0.0.0/16"
        cidr_blocks                      = ["10.0.0.0/16"]
        ipv6cidr_blocks                  = []
        ipv6private_cidr_blocks          = []
        byoipv6cidr_blocks               = []
        byoipv6cidr_details              = []
        is_ipv6enabled                   = true
        is_oracle_gua_allocation_enabled = true
        default_dhcp_options_id          = "ocid1.dhcpoptions.oc1..test"
        default_route_table_id           = "ocid1.routetable.oc1..test"
        default_security_list_id         = "ocid1.securitylist.oc1..test"
        defined_tags                     = {}
        freeform_tags                    = {}
        security_attributes              = {}
      }]
    }
  }
}

variables {
  tenancy_ocid     = "ocid1.tenancy.oc1..test"
  user_ocid        = "ocid1.user.oc1..test"
  fingerprint      = "00:00"
  private_key      = "test"
  region           = "eu-frankfurt-1"
  state_passphrase = "a passphrase for the tests"
  state_path       = "terraform.tfstate"
  public_ports = [
    { port = 443, protocol = "tcp", service = "Traefik" },
    { port = 49160, last_port = 49200, protocol = "udp", service = "coturn relays" },
  ]
}

run "every_port_opens_for_both_families" {
  command = plan

  assert {
    condition     = length(local.port_rules) == 4
    error_message = "Each public port should give one IPv4 and one IPv6 rule."
  }

  assert {
    condition = anytrue([
      for rule in local.port_rules :
      rule.protocol == "17" && rule.source == "::/0" && rule.first_port == 49160 && rule.last_port == 49200
    ])
    error_message = "A port range should keep its first and last port."
  }

  assert {
    condition     = alltrue([for rule in local.port_rules : rule.first_port == rule.last_port if rule.protocol == "6"])
    error_message = "A single port should be its own range."
  }
}

run "ssh_is_never_public" {
  command = plan

  assert {
    condition     = !anytrue([for rule in local.port_rules : rule.first_port <= 22 && 22 <= rule.last_port])
    error_message = "SSH goes through the VPN only."
  }
}

run "an_unknown_protocol_is_refused" {
  command = plan

  variables {
    public_ports = [{ port = 22, protocol = "sctp", service = "Wrong" }]
  }

  expect_failures = [var.public_ports]
}
