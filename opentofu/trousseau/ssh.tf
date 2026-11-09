# Two certificate authorities, whose private keys never leave OpenBao: one
# signs the keys people and Ansible log in with, the other the hosts' keys
# (so that clients trust a host without asking)

resource "vault_mount" "users" {
  path        = "ssh-utilisateurs"
  type        = "ssh"
  description = "Certificates of the accounts logging in to the hosts"
}

resource "vault_ssh_secret_backend_ca" "users" {
  backend              = vault_mount.users.path
  generate_signing_key = true
  key_type             = "ed25519"
}

# The owner's account, for a working day
resource "vault_ssh_secret_backend_role" "alix" {
  backend                 = vault_mount.users.path
  name                    = "alix"
  key_type                = "ca"
  allow_user_certificates = true
  allowed_users           = "alix_anneraud"
  default_user            = "alix_anneraud"
  allowed_extensions      = "permit-pty,permit-port-forwarding,permit-agent-forwarding"
  default_extensions = {
    "permit-pty"             = ""
    "permit-port-forwarding" = ""
  }
  ttl     = var.user_certificate_ttl
  max_ttl = var.user_certificate_ttl

  depends_on = [vault_ssh_secret_backend_ca.users]
}

# Ansible's account: only from the LAN and the VPN, as its keys today
resource "vault_ssh_secret_backend_role" "ansible" {
  backend                  = vault_mount.users.path
  name                     = "ansible"
  key_type                 = "ca"
  allow_user_certificates  = true
  allowed_users            = "ansible"
  default_user             = "ansible"
  allowed_critical_options = "source-address"
  default_critical_options = {
    "source-address" = join(",", var.automation_ssh_sources)
  }
  allowed_extensions = "permit-pty"
  default_extensions = {
    "permit-pty" = ""
  }
  ttl     = var.user_certificate_ttl
  max_ttl = var.user_certificate_ttl

  depends_on = [vault_ssh_secret_backend_ca.users]
}

resource "vault_mount" "hosts" {
  path                      = "ssh-hotes"
  type                      = "ssh"
  description               = "Certificates of the hosts' keys"
  default_lease_ttl_seconds = var.host_certificate_ttl
  max_lease_ttl_seconds     = var.host_certificate_ttl
}

resource "vault_ssh_secret_backend_ca" "hosts" {
  backend              = vault_mount.hosts.path
  generate_signing_key = true
  key_type             = "ed25519"
}

# A host's names (luxembourg.anneraud.fr, local.luxembourg.anneraud.fr...)
resource "vault_ssh_secret_backend_role" "hosts" {
  backend                 = vault_mount.hosts.path
  name                    = "hotes"
  key_type                = "ca"
  allow_host_certificates = true
  allowed_domains         = "anneraud.fr"
  allow_subdomains        = true
  allow_bare_domains      = false
  ttl                     = var.host_certificate_ttl
  max_ttl                 = var.host_certificate_ttl

  depends_on = [vault_ssh_secret_backend_ca.hosts]
}
