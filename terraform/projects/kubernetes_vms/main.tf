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

  # Per-role simple overrides merged over vm_attr defaults (null keeps the default)
  role_overrides = {
    for role, cfg in var.vm_attr : role => lookup({
      "master" = { ram = var.master_ram != null ? var.master_ram * 1024 : null, cpu = var.master_cpu, vlan = var.master_vlan }
      "worker" = { ram = var.worker_ram != null ? var.worker_ram * 1024 : null, cpu = var.worker_cpu, vlan = var.worker_vlan }
    }, role, {})
  }

  effective_vm_attr = {
    for role, cfg in var.vm_attr : role => merge(cfg, {
      for attr, value in local.role_overrides[role] : attr => value if value != null
    })
  }

  # Control plane (max_per_node = 1): one VM per node, only on nodes with enough free memory
  cp_role = [for role, cfg in local.effective_vm_attr : role if cfg.max_per_node == 1][0]
  cp_attr = local.effective_vm_attr[local.cp_role]

  cp_feasible = [
    for node in local.node_order : node
    if local.node_free[node] >= local.cp_attr.ram
  ]

  cp_nodes = length(local.cp_feasible) >= local.cp_attr.count ? [
    for i in range(local.cp_attr.count) : local.cp_feasible[i]
  ] : []

  cp_hosts = toset(local.cp_nodes)

  # Residual capacity per node after control-plane VMs are reserved
  residual_mib = {
    for node in local.node_order :
    node => local.node_free[node] - (contains(local.cp_hosts, node) ? local.cp_attr.ram : 0)
  }

  max_residual_mib = length(local.node_order) > 0 ? max([for node in local.node_order : local.residual_mib[node]]...) : 0

  # Remaining roles (max_per_node != 1): pack nodes with residual capacity, most available first
  pack_roles = [for role, cfg in local.effective_vm_attr : role if cfg.max_per_node != 1]

  pack_slots = {
    for role in local.pack_roles : role => {
      for node in local.node_order :
      node => min(
        floor(local.residual_mib[node] / local.effective_vm_attr[role].ram),
        local.effective_vm_attr[role].max_per_node == 0
        ? floor(local.residual_mib[node] / local.effective_vm_attr[role].ram)
        : local.effective_vm_attr[role].max_per_node
      )
    }
  }

  pack_precedence = {
    for role in local.pack_roles : role => [
      for key in sort([
        for node in local.node_order :
        "${format("%012d", local.max_residual_mib - local.residual_mib[node])}|${node}"
        if local.pack_slots[role][node] >= 1
      ]) : split("|", key)[1]
    ]
  }

  pack_slots_list = {
    for role in local.pack_roles : role =>
    [for node in local.pack_precedence[role] : local.pack_slots[role][node]]
  }

  # Water-fill: each node takes VMs until it runs out of capacity or demand is met
  pack_placed = {
    for role in local.pack_roles : role => [
      for i in range(length(local.pack_precedence[role])) :
      min(local.pack_slots_list[role][i], max(0, local.effective_vm_attr[role].count - try(sum([for j in range(i) : local.pack_slots_list[role][j]]), 0)))
    ]
  }

  pack_prefix = {
    for role in local.pack_roles : role => [
      for i in range(length(local.pack_placed[role])) :
      try(sum([for j in range(i) : local.pack_placed[role][j]]), 0)
    ]
  }

  cp_placements = [
    for i in range(length(local.cp_nodes)) : {
      vm_name = "kub-${var.vm_env}-${substr(local.cp_role, 0, 1)}${format("%01d", i + 1)}"
      vm_role = local.cp_role
      vm_node = local.cp_nodes[i]
    }
  ]

  pack_placements = flatten([
    for role in local.pack_roles : [
      for p in range(length(local.pack_precedence[role])) : [
        for k in range(local.pack_placed[role][p]) : {
          vm_name = "kub-${var.vm_env}-${substr(role, 0, 1)}${format("%01d", local.pack_prefix[role][p] + k + 1)}"
          vm_role = role
          vm_node = local.pack_precedence[role][p]
        }
      ]
    ]
  ])

  vm_list = {
    for vm in concat(local.cp_placements, local.pack_placements) :
    vm.vm_name => {
      node_name = vm.vm_node
      vm_cpu    = local.effective_vm_attr[vm.vm_role].cpu
      vm_ram    = local.effective_vm_attr[vm.vm_role].ram
      vm_vlan   = local.effective_vm_attr[vm.vm_role].vlan
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

check "control_plane_capacity" {
  assert {
    condition     = length(local.cp_nodes) == local.cp_attr.count
    error_message = "Cannot place ${local.cp_attr.count} ${local.cp_role} VM(s): only ${length(local.cp_feasible)} online node(s) have at least ${local.cp_attr.ram} MiB free memory."
  }
}

check "pack_capacity" {
  assert {
    condition = length(local.pack_roles) == 0 ? true : alltrue([
      for role in local.pack_roles :
      try(sum(local.pack_placed[role]), 0) == local.effective_vm_attr[role].count
    ])
    error_message = "Cannot place all pack VMs: ${join(", ", [
      for role in local.pack_roles :
      "${role} needs ${local.effective_vm_attr[role].count} VM(s) (${local.effective_vm_attr[role].ram} MiB each), residual free capacity fits only ${try(sum(local.pack_placed[role]), 0)} VM(s)."
      if try(sum(local.pack_placed[role]), 0) != local.effective_vm_attr[role].count
    ])}"
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