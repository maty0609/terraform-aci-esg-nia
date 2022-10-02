locals {
  #loops through variables in service (terraform.tfvars file)
  service_payload            = [for _, s in var.services : s if s.status == "passing"]
  #Compute new cts service block, adding ACI specific information to it. This enables for_each meta argument to loop through ACI and cts data within the same resource block.
  synthetic_payload          = [for s in local.service_payload : merge(s, { esg = format("%s-%s-svc", var.esg_prefix, s.name), match_expression = format("ip=='%s'", s.address == "" ? s.node_address : s.address) })]


}

data "aci_tenant" "showcase" {
  name = var.tenant_name
}

data "aci_tenant" "common" {
  name = "common"
}

data "aci_application_profile" "hashiconf2022" {
  name = "hashiconf2022"
  tenant_dn = data.aci_tenant.showcase.id
}

data "aci_bridge_domain" "hashiconf2022" {
  tenant_dn  = data.aci_tenant.showcase.id
  name = "uk-dc-showcase-production-bd"
}

data "aci_contract" "inet" {
  tenant_dn  =  data.aci_tenant.common.id
  name       = "inet"
}

data "aci_contract" "consul" {
  tenant_dn  =  data.aci_tenant.showcase.id
  name       = "kubernetes-to-dc-showcase"
}

# resource "aci_filter" "hashi2022-app" {
# 	tenant_dn = data.aci_tenant.showcase.id
# 	name      = "hashi2022-app"
# }

# resource "aci_contract_subject" "hashi2022-app" {
# 	contract_dn                  = aci_contract.hashi2022-app.id
# 	name                         = "hashi2022-app"
# 	relation_vz_rs_subj_filt_att = [aci_filter.hashi2022-app.id]
# }

# resource "aci_filter_entry" "hashi2022-app" {
#   name        = "hashi2022-app"
#   filter_dn   = aci_filter.hashi2022-app.id
#   ether_t     = "ip"
#   prot        = "tcp"
#   stateful    = "no"
# }

# resource "aci_contract" "hashi2022-app" {
# 	tenant_dn = data.aci_tenant.showcase.id
# 	name      = "hashi2022-app"
# }

resource "aci_application_epg" "hashiconf2022" {
  for_each               = { for _, policy in distinct([for s in local.synthetic_payload : s.esg]) : policy => policy }
  application_profile_dn  = data.aci_application_profile.hashiconf2022.id
  name = each.value
  relation_fv_rs_bd = data.aci_bridge_domain.hashiconf2022.id
  relation_fv_rs_cons = [data.aci_contract.inet.id]
  relation_fv_rs_prov = [data.aci_contract.consul.id]
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
