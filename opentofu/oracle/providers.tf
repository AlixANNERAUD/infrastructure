# A user of its own (opentofu-reseau), whose group may only manage the
# network's security lists and read the rest of the network
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key
  region       = var.region
}
