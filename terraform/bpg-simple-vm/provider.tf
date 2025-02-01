terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure = false
  ssh {
    agent    = true
    username = "root"
  } 
}
