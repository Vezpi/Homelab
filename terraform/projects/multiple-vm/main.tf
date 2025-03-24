module "pve_vm" {
  source    = "../../modules/pve_vm"
  for_each = toset(data.proxmox_virtual_environment_nodes.pve_nodes.names)
  node_name = each.value
  vm_name   = "${each.value}-vm"
  vm_cpu    = 2
  vm_ram    = 2048
  vm_vlan   = 66
}

data "proxmox_virtual_environment_nodes"  "pve_nodes" {} 

output "vm_ip" {
  value = { for k, v in module.pve_vm : "${k}-vm" => v.vm_ip }
}