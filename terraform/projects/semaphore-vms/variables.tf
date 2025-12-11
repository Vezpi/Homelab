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