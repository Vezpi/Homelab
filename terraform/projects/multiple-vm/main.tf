module "pve_vm" {
  source    = "../../modules/pve_vm"
  for_each  = var.node_list
  node_name = each.value
  vm_name   = "${each.value}-vm"
  vm_cpu    = 2
  vm_ram    = 2048
  vm_vlan   = 66
}

output "vm_ip" {
  value = { for k, v in module.pve_vm : "${k}-vm" => v.vm_ip }
}