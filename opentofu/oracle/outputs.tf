output "public_rules" {
  description = "Public rules of the security list, for the playbook's summary."
  value       = [for rule in local.port_rules : rule.description]
}
