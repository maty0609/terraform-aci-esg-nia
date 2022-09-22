terraform {
  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = ">= 0.4.1"
    }
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">=1.26.0"
    }
  }
  required_version = ">= 0.13"
}
