# Everything, for the Zitadel administrator and the deployments' AppRole. The
# first start writes the same policy, so that the AppRole works before this
# configuration is applied
resource "vault_policy" "administration" {
  name   = "administration"
  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
    }
  EOT
}
