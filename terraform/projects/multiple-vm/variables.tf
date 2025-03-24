variable "proxmox_endpoint" {
  description = "Proxmox URL endpoint"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "node_list" {
  description = "List of node names in the Proxmox cluster"
  type        = set(string)
  default     = ["apex", "vertex", "zenith"]
}