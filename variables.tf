variable "vsphere_datacenter" {
  description = "variable for the datacenter where the VMs will be deployed"
  type        = string
  default     = "ukdcb_production"
}

variable "services" {
  description = "Consul services monitored by Consul NIA"
  type = map(
    object({
      id        = string
      name      = string
      address   = string
      port      = number
      status    = string
      meta      = map(string)
      tags      = list(string)
      namespace = string

      node                  = string
      node_id               = string
      node_address          = string
      node_datacenter       = string
      node_tagged_addresses = map(string)
      node_meta             = map(string)
    })
  )
}

variable "tenant_name" {}
variable "application_profile_name" {}
variable "vrf_name" {}
variable "esg_prefix" {}
