module "pve_vm" {
  source            = "../../modules/pve_vm"
  node_name         = "zenith"
  vm_name           = "zenith-vm"
  vm_cpu            = 2
  vm_ram            = 2048
  vm_vlan           = 66
  proxmox_endpoint  = var.proxmox_endpoint
  proxmox_api_token = var.proxmox_api_token
}

output "vm_ip" {
  value = module.pve_vm.vm_ip
}