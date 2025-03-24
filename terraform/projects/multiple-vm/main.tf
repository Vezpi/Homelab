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
  vm_attr = {
    "master" = { ram = 2048, cpu = 2, vlan = 66 }
    "worker" = { ram = 1024, cpu = 1, vlan = 66 }
  }

  vm_list = {
    for vm in flatten([
      for node in data.proxmox_virtual_environment_nodes.pve_nodes.names : [
        for role, config in local.vm_attr : {
          node_name = node
          vm_name   = "${role}-${node}"
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