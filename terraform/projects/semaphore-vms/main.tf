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
  # Ordered list of VM hostnames
  sem_hosts = ["sem01", "sem02", "sem03"]

  # Create a map: host -> node
  vm_list = {
    for idx, host in local.sem_hosts :
    host => {
      node_name = data.proxmox_virtual_environment_nodes.pve_nodes.names[idx]
      vm_name   = host
      vm_cpu    = 1
      vm_ram    = 2048
      vm_vlan   = 66
    }
  }
}

data "proxmox_virtual_environment_nodes" "pve_nodes" {}

output "vm_ip" {
  value = { for k, v in module.pve_vm : k => v.vm_ip }
}
