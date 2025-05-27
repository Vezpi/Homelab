# Define the required Terraform provider block
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox" # Use the community Proxmox provider from the bpg namespace
    }
  }
}

# Configure the Proxmox provider with API and SSH access
provider "proxmox" {
  endpoint  = var.proxmox_endpoint  # Proxmox API URL (e.g., https://proxmox.local:8006/api2/json)
  api_token = var.proxmox_api_token # API token for authentication (should have appropriate permissions)
  insecure  = false                 # Reject self-signed or invalid TLS certificates (set to true only in trusted/test environments)

  # Optional SSH settings used for VM customization via SSH
  ssh {
    agent       = false                        # Do not use the local SSH agent; use key file instead
    private_key = file("~/.ssh/id_ed25519")    # Load SSH private key from the local file system
    username    = "root"                       # SSH username for connecting to the Proxmox host
  }
}