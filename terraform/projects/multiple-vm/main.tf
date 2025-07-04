module "pve_vm" {
  source    = "../../modules/pve_vm"
  for_each  = local.vm_list
  node_name = each.value.node_name
  vm_name   = each.value.vm_name
  vm_cpu    = each.value.vm_cpu
  vm_ram    = each.value.vm_ram
  vm_vlan   = each.value.vm_vlan
  proxmox_endpoint  = var.proxmox_endpoint
  proxmox_api_token = var.proxmox_api_token
}

locals {
  vm_list = {
    for vm in flatten([
      for node in data.proxmox_virtual_environment_nodes.pve_nodes.names : {
        node_name = node
        vm_name   = "${role}-${node}"
        vm_cpu    = config.cpu
        vm_ram    = config.ram
        vm_vlan   = config.vlan
      }
    ]) : vm.vm_name => vm
  }
}

data "proxmox_virtual_environment_nodes" "pve_nodes" {}

output "vm_ip" {
  value = { for k, v in module.pve_vm : k => v.vm_ip }
}