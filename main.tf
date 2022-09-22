locals {
  #loops through variables in service (terraform.tfvars file)
  service_payload            = [for _, s in var.services : s if s.status == "passing"]
  #Compute new cts service block, adding ACI specific information to it. This enables for_each meta argument to loop through ACI and cts data within the same resource block.
  synthetic_payload          = [for s in local.service_payload : merge(s, { esg = format("%s-%s-svc", var.esg_prefix, s.name), match_expression = format("ip=='%s'", s.address == "" ? s.node_address : s.address) })]


}

data "aci_tenant" "this" {
  name = var.tenant_name
}
data "aci_application_profile" "this" {
  name = var.application_profile_name
  tenant_dn = data.aci_tenant.this.id
}
data "aci_vrf" "this" {
  name = var.vrf_name
  tenant_dn = data.aci_tenant.this.id
}

data "aci_bridge_domain" "this" {
  tenant_dn  = data.aci_tenant.this.id
  name = "uk-dc-showcase-production-bd"
}

# resource "aci_endpoint_security_group" "this" {
#   #Loop through the list of unique services that need to be created
#   for_each               = { for _, policy in distinct([for s in local.synthetic_payload : s.esg]) : policy => policy }
#   application_profile_dn = data.aci_application_profile.this.id
#   relation_fv_rs_scope   = data.aci_vrf.this.id
#   name                   = each.value
# }

# resource "aci_endpoint_security_group_selector" "this" {
#   #Loop through the list of compute instances and map them to the corresponding service redirection policy and associated VIP
#   for_each                   = { for _, s in local.synthetic_payload : s.id => s }
#   endpoint_security_group_dn  = aci_endpoint_security_group.this[each.value.esg].id
#   match_expression             = each.value.match_expression
#   description                  = "Service instance ${each.value.id} on node ${each.value.node}"
# }

resource "aci_application_epg" "dc-showcase-apps" {
  for_each               = { for _, policy in distinct([for s in local.synthetic_payload : s.esg]) : policy => policy }
  application_profile_dn  = data.aci_application_profile.this.id
  name = each.value
  relation_fv_rs_bd = data.aci_bridge_domain.this.id
}

# data block to fetch the datacenter id
data "vsphere_datacenter" "dc" {
  name = "ukdcb_production"
}

data "vsphere_datastore" "datastore" {
  name          = "showcase-dc"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "showcase_dc|clus2022|cts-app-svc"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "compute_cluster" {
  name          = "cluster-natilik/Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "aci_vmm_domain" "vds" {
	provider_profile_dn = "uni/vmmp-VMware"
	name                = "vds_1"
}

resource "aci_epg_to_domain" "kubernetes" {
  for_each = aci_application_epg.dc-showcase-apps
  application_epg_dn    = each.value.id
  tdn                   = data.aci_vmm_domain.vds.id
}

resource "vsphere_virtual_machine" "vm" {
  name             = "app01"
  resource_pool_id = data.vsphere_resource_pool.compute_cluster.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "showcase/dc/clus2022"

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
  }
  disk {
    label            = "os"
    size             = 50
  }

}
