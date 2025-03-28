variable "proxmox_endpoint" {
  description = "Proxmox URL endpoint"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "multi_node_deployment" {
  description = "true : deploy VMs on each node, false : deploy only on a given node"
  type        = bool
  default     = true
}

variable "target_node" {
  description = "Node which host the VM if multi_node_deployment = false"
  type        = string
  default     = ""
}

variable "vm_attr" {
  description = "VM attributes"
  type = map(object({
    ram  = number
    cpu  = number
    vlan = number
  }))
  default = {
    "vm" = { ram = 2048, cpu = 2, vlan = 66 }
  }
}