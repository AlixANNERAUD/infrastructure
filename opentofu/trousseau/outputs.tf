# Public keys of the certificate authorities: the hosts trust the first
# (TrustedUserCAKeys), the clients the second (@cert-authority in known_hosts)
output "user_certificate_authority" {
  value = vault_ssh_secret_backend_ca.users.public_key
}

output "host_certificate_authority" {
  value = vault_ssh_secret_backend_ca.hosts.public_key
}
