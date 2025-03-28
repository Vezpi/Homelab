module "pve_vm" {
  source    = "../../modules/pve_vm"
  for_each  = local.vm_list
  node_name = each.value.node_name
  vm_name   = each.value.vm_name
  vm_cpu    = each.value.vm_cpu
  vm_ram    = each.value.vm_ram
  vm_vlan   = each.value.vm_vlan
}

locals {
  all_nodes = data.proxmox_virtual_environment_nodes.pve_nodes.names

  selected_nodes = var.multi_node_deployment == false ? [var.target_node] : local.all_nodes

  vm_list = {
    for vm in flatten([
      for node in local.selected_nodes : [
        for role, config in var.vm_attr : {
          node_name = node
          vm_name   = "${node}-${role}"
          vm_cpu    = config.cpu
          vm_ram    = config.ram
          vm_vlan   = config.vlan
        }
      ]
    ]) : vm.vm_name => vm
  }
}

data "proxmox_virtual_environment_nodes" "pve_nodes" {}

output "vm_ip" {
  value = { for k, v in module.pve_vm : k => v.vm_ip }
}

resource "ansible_group" "servers" {
  name = "servers"
}
resource "ansible_host" "vm" {
  for_each = module.pve_vm
  name     = each.key
  variables = {
    ansible_host = each.value.vm_ip
  }
  groups = ["servers"]
}