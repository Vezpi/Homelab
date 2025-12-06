variable "node_name" {
  description = "Proxmox host for the VM"
  type        = string
}

variable "node_datastore" {
  description = "Datastore used for VM storage"
  type        = string
  default     = "ceph-workload"
}

variable "vm_template" {
  description = "Template of the VM"
  type        = string
  default     = "ubuntu-cloud"
}

variable "vm_name" {
  description = "Hostname of the VM"
  type        = string
}

variable "vm_user" {
  description = "Admin user of the VM"
  type        = string
  default     = "vez"
}

variable "vm_user_sshkeys" {
  description = "Admin user SSH keys of the VM"
  type        = list(string)
  default     = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID62LmYRu1rDUha3timAIcA39LtcIOny1iAgFLnxoBxm vez@bastion",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHovfHKpqTvwj5zrcSuSZALa8iiH6qBvE5dyJCz9eQ2k vez@surface"
  ]
}

variable "vm_cpu" {
  description = "Number of CPU cores of the VM"
  type        = number
  default     = 1
}

variable "vm_ram" {
  description = "Number of RAM (MB) of the VM"
  type        = number
  default     = 2048
}

variable "vm_disk_size" {
  description = "Size of the disk (GB) of the VM"
  type        = number
  default     = 10
}

variable "vm_bios" {
  description = "Type of BIOS used for the VM"
  type        = string
  default     = "ovmf"
}

variable "vm_machine" {
  description = "Type of machine used for the VM"
  type        = string
  default     = "q35"
}

variable "vm_vlan" {
  description = "VLAN of the VM"
  type        = number
  default     = 66
}

variable "vm_tags" {
  description = "Tags for the VM"
  type        = list(any)
  default     = ["test"]
}