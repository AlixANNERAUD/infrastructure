variable "public_ports" {
  description = <<-EOT
    Ports open to the internet, from both IPv4 and IPv6: host_firewall_public_ports
    in inventory/host_vars/luxembourg.yml, which the host's iptables use too.
  EOT
  type = list(object({
    port      = number
    last_port = optional(number)
    protocol  = string
    service   = string
  }))

  validation {
    condition     = alltrue([for entry in var.public_ports : contains(["tcp", "udp"], entry.protocol)])
    error_message = "Each port's protocol is tcp or udp."
  }
}

variable "tenancy_ocid" {
  type      = string
  sensitive = true
}

variable "user_ocid" {
  type      = string
  sensitive = true
}

variable "fingerprint" {
  type      = string
  sensitive = true
}

variable "private_key" {
  description = "The API key of opentofu-reseau, in PEM."
  type        = string
  sensitive   = true
}

variable "region" {
  type = string
}

variable "state_passphrase" {
  type      = string
  sensitive = true
}

variable "state_path" {
  type = string
}
