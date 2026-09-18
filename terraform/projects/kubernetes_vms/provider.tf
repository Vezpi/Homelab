terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    ansible = {
      source = "ansible/ansible"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = false
  ssh {
    agent       = false
    username    = var.proxmox_ssh_username
    password    = var.proxmox_ssh_password
  }
}