module "pve_vm" {
  source    = "../../modules/pve_vm"
  for_each  = local.vm_list
  node_name = each.value.node_name
  vm_name   = each.key
  vm_cpu    = each.value.vm_cpu
  vm_ram    = each.value.vm_ram
  vm_vlan   = each.value.vm_vlan
  vm_tags   = ["${var.vm_env}"]
}

locals {
  node_stats = [
    for i, name in data.proxmox_virtual_environment_nodes.pve_nodes.names : {
      name     = name
      free_mib = floor(data.proxmox_virtual_environment_nodes.pve_nodes.memory_available[i] / 1024 / 1024)
    }
    if data.proxmox_virtual_environment_nodes.pve_nodes.online[i]
  ]

  max_free_mib = length(local.node_stats) > 0 ? max([for node in local.node_stats : node.free_mib]...) : 0

  # Online nodes ordered by available memory, most available first (name as tie-break)
  node_order = [
    for key in sort([
      for node in local.node_stats : "${format("%012d", local.max_free_mib - node.free_mib)}|${node.name}"
    ]) : split("|", key)[1]
  ]

  vm_layout = flatten([
    for role in ["master", "worker"] : [
      for i in range(role == "master" ? var.master_count : var.worker_count) : {
        vm_name   = "kub-${var.vm_env}-${substr(role, 0, 1)}${format("%02d", i + 1)}"
        seq_index = (role == "master" ? 0 : var.master_count) + i
        vm_role   = role
      }
    ]
  ])

  vm_list = {
    for vm in local.vm_layout :
    vm.vm_name => {
      node_name = length(local.node_order) > 0 ? local.node_order[vm.seq_index % length(local.node_order)] : ""
      vm_cpu    = var.vm_attr[vm.vm_role].cpu
      vm_ram    = var.vm_attr[vm.vm_role].ram
      vm_vlan   = var.vm_attr[vm.vm_role].vlan
      vm_role   = vm.vm_role
    }
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