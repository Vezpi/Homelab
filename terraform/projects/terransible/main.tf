module "pve_vm" {
  source    = "../../modules/pve_vm"
  for_each  = local.vm_list
  node_name = each.value.node_name
  vm_name   = each.value.vm_name
  vm_cpu    = each.value.vm_cpu
  vm_ram    = each.value.vm_ram
  vm_vlan   = each.value.vm_vlan
  vm_tags   = var.vm_tags
}

locals {
  all_nodes = data.proxmox_virtual_environment_nodes.pve_nodes.names

  selected_nodes = var.multi_node_deployment == false ? [var.target_node] : local.all_nodes

  env_digit_map = {
    "test" = 1
    "lab"  = 2
    "dev"  = 3
    "val"  = 4
    "prod" = 5
  }

  env_digit = lookup(local.env_digit_map, var.vm_env, 0)

  vm_list = {
    for vm in flatten([
      for node in local.selected_nodes : [
        for role, config in var.vm_attr : {
          node_name = node
          vm_name   = "${role}-${var.vm_env}-${node}"
          vm_name   = "kub-${substr(role, 0, 1)}${local.env_digit}${substr(node, 0, 1)}"
          vm_cpu    = config.cpu
          vm_ram    = config.ram
          vm_vlan   = config.vlan
          vm_role   = role
        }
      ]
    ]) : vm.vm_name => vm
  }

  roles = toset([for vm in local.vm_list : vm.vm_role])
}

data "proxmox_virtual_environment_nodes" "pve_nodes" {}

output "vm_ip" {
  value = { for k, v in module.pve_vm : k => v.vm_ip }
}

resource "ansible_group" "vm_groups" {
  for_each = local.roles
  name     = each.key
}
resource "ansible_host" "vm_hosts" {
  for_each = module.pve_vm
  name     = each.key
  variables = {
    ansible_host = each.value.vm_ip
  }
  groups = [local.vm_list[each.key].vm_role]
}