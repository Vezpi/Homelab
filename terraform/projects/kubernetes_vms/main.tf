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

  node_free = { for node in local.node_stats : node.name => node.free_mib }

  master_ram = var.vm_attr.master.ram
  worker_ram = var.vm_attr.worker.ram

  # Masters: one per node, only on nodes with enough free memory
  feasible_masters = [
    for node in local.node_order : node
    if local.node_free[node] >= local.master_ram
  ]

  master_nodes = length(local.feasible_masters) >= var.master_count ? [
    for i in range(var.master_count) : local.feasible_masters[i]
  ] : []

  master_hosts = toset(local.master_nodes)

  # Residual capacity per node after masters are reserved
  residual_mib = {
    for node in local.node_order :
    node => local.node_free[node] - (contains(local.master_hosts, node) ? local.master_ram : 0)
  }

  max_residual_mib = length(local.node_order) > 0 ? max([for node in local.node_order : local.residual_mib[node]]...) : 0

  worker_slots = {
    for node in local.node_order : node => floor(local.residual_mib[node] / local.worker_ram)
  }

  # Workers: pack nodes with residual capacity, most available first (name as tie-break)
  worker_precedence = [
    for key in sort([
      for node in local.node_order :
      "${format("%012d", local.max_residual_mib - local.residual_mib[node])}|${node}"
      if local.worker_slots[node] >= 1
    ]) : split("|", key)[1]
  ]

  worker_slots_list = [for node in local.worker_precedence : local.worker_slots[node]]

  # Water-fill: each node takes workers until it runs out of capacity or demand is met
  worker_placed = [
    for i in range(length(local.worker_precedence)) :
    min(local.worker_slots_list[i], max(0, var.worker_count - try(sum([for j in range(i) : local.worker_slots_list[j]]), 0)))
  ]

  worker_prefix = [
    for i in range(length(local.worker_placed)) :
    try(sum([for j in range(i) : local.worker_placed[j]]), 0)
  ]

  master_placements = [
    for i in range(length(local.master_nodes)) : {
      vm_name = "kub-${var.vm_env}-m${format("%02d", i + 1)}"
      vm_role = "master"
      vm_node = local.master_nodes[i]
    }
  ]

  worker_placements = flatten([
    for p in range(length(local.worker_precedence)) : [
      for k in range(local.worker_placed[p]) : {
        vm_name = "kub-${var.vm_env}-w${format("%02d", local.worker_prefix[p] + k + 1)}"
        vm_role = "worker"
        vm_node = local.worker_precedence[p]
      }
    ]
  ])

  vm_list = {
    for vm in concat(local.master_placements, local.worker_placements) :
    vm.vm_name => {
      node_name = vm.vm_node
      vm_cpu    = var.vm_attr[vm.vm_role].cpu
      vm_ram    = var.vm_attr[vm.vm_role].ram
      vm_vlan   = var.vm_attr[vm.vm_role].vlan
      vm_role   = vm.vm_role
    }
  }

  roles = toset([for vm in local.vm_list : vm.vm_role])
}

data "proxmox_virtual_environment_nodes" "pve_nodes" {}

check "proxmox_nodes" {
  assert {
    condition     = length(local.node_order) > 0
    error_message = "No online Proxmox node available for deployment."
  }
}

check "master_capacity" {
  assert {
    condition     = length(local.master_nodes) == var.master_count
    error_message = "Cannot place ${var.master_count} master(s): only ${length(local.feasible_masters)} online node(s) have at least ${local.master_ram} MiB free memory."
  }
}

check "worker_capacity" {
  assert {
    condition     = try(sum(local.worker_placed), 0) == var.worker_count
    error_message = "Cannot place ${var.worker_count} worker(s) (${local.worker_ram} MiB each): residual free capacity on online nodes fits only ${try(sum(local.worker_placed), 0)} worker(s)."
  }
}

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