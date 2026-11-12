# Every peer resolves through Cloudflare, except the names below, which point
# straight at Bruxelles' LAN address
resource "netbird_nameserver_group" "cloudflare" {
  name                   = "Cloudflare DNS"
  description            = "Cloudflare DNS Servers"
  groups                 = [data.netbird_group.all.id]
  primary                = true
  domains                = []
  search_domains_enabled = false
  enabled                = true

  nameservers = [
    { ip = "1.1.1.1", ns_type = "udp", port = 53 },
    { ip = "1.0.0.1", ns_type = "udp", port = 53 },
  ]
}

resource "netbird_dns_zone" "zone" {
  for_each = toset(["anneraud.fr", "minitrainstore.fr"])

  name                 = each.value
  domain               = each.value
  distribution_groups  = [data.netbird_group.all.id]
  enable_search_domain = false
  enabled              = true
}

resource "netbird_dns_record" "bruxelles" {
  for_each = toset(["mediatheque", "nuage", "maison", "wakapi", "s"])

  zone_id = netbird_dns_zone.zone["anneraud.fr"].id
  name    = "${each.value}.anneraud.fr"
  type    = "A"
  content = "192.168.0.21"
  ttl     = 300
}
