variable "proxmox_endpoint" {
  description = "Proxmox URL endpoint"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_username" {
  description = "Proxmox SSH username"
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_password" {
  description = "Proxmox SSH password"
  type        = string
  sensitive   = true
}

variable "vm_attr" {
  description = "VM attributes per role. max_per_node = 0 means unlimited VMs per node."
  type = map(object({
    ram          = number
    cpu          = number
    vlan         = number
    count        = number
    max_per_node = number
  }))
  default = {
    "master" = { ram = 2048, cpu = 2, vlan = 66, count = 3, max_per_node = 1 }
    "worker" = { ram = 4096, cpu = 2, vlan = 66, count = 3, max_per_node = 0 }
  }

  validation {
    condition     = alltrue([for v in values(var.vm_attr) : v.count >= 1])
    error_message = "Each role must deploy at least 1 VM."
  }

  validation {
    condition     = alltrue([for v in values(var.vm_attr) : v.max_per_node >= 0])
    error_message = "max_per_node must be 0 (unlimited) or a positive number."
  }

  validation {
    condition     = length([for v in values(var.vm_attr) : v if v.max_per_node == 1]) == 1
    error_message = "Exactly one role must have max_per_node = 1 (the control-plane role)."
  }
}

variable "master_cpu" {
  description = "Master role CPU override. null keeps the vm_attr default."
  type        = number
  default     = null

  validation {
    condition     = var.master_cpu == null || var.master_cpu >= 1
    error_message = "master_cpu must be null or at least 1."
  }
}

variable "master_ram" {
  description = "Master role RAM override in GiB (converted to MiB internally). null keeps the vm_attr default."
  type        = number
  default     = null

  validation {
    condition     = var.master_ram == null || var.master_ram >= 1
    error_message = "master_ram must be null or at least 1 GiB."
  }
}

variable "master_vlan" {
  description = "Master role VLAN override. null keeps the vm_attr default."
  type        = number
  default     = null

  validation {
    condition     = var.master_vlan == null || var.master_vlan >= 1
    error_message = "master_vlan must be null or at least 1."
  }
}

variable "worker_cpu" {
  description = "Worker role CPU override. null keeps the vm_attr default."
  type        = number
  default     = null

  validation {
    condition     = var.worker_cpu == null || var.worker_cpu >= 1
    error_message = "worker_cpu must be null or at least 1."
  }
}

variable "worker_ram" {
  description = "Worker role RAM override in GiB (converted to MiB internally). null keeps the vm_attr default."
  type        = number
  default     = null

  validation {
    condition     = var.worker_ram == null || var.worker_ram >= 1
    error_message = "worker_ram must be null or at least 1 GiB."
  }
}

variable "worker_vlan" {
  description = "Worker role VLAN override. null keeps the vm_attr default."
  type        = number
  default     = null

  validation {
    condition     = var.worker_vlan == null || var.worker_vlan >= 1
    error_message = "worker_vlan must be null or at least 1."
  }
}

variable "vm_env" {
  description = "VM environment"
  type        = string
  default     = "prod"
}