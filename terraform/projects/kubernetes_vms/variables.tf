variable "proxmox_endpoint" {
  description = "Proxmox URL endpoint"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Node which hosts the VMs when set; otherwise a node is selected based on available resources"
  type        = string
  default     = ""
}

variable "master_count" {
  description = "Number of Kubernetes control-plane (master) VMs to deploy"
  type        = number
  default     = 3

  validation {
    condition     = var.master_count >= 1
    error_message = "master_count must be at least 1."
  }
}

variable "worker_count" {
  description = "Number of Kubernetes worker VMs to deploy"
  type        = number
  default     = 3

  validation {
    condition     = var.worker_count >= 1
    error_message = "worker_count must be at least 1."
  }
}

variable "vm_attr" {
  description = "VM attributes"
  type = map(object({
    ram  = number
    cpu  = number
    vlan = number
  }))
  default = {
    "master" = { ram = 2048, cpu = 2, vlan = 66 }
    "worker" = { ram = 4096, cpu = 2, vlan = 66 }
  }
}

variable "vm_env" {
  description = "VM environment"
  type        = string
  default     = "prod"
}

variable "vm_tags" {
  description = "Tags for the VM"
  type        = list(any)
  default     = ["prod"]
}