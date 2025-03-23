module "pve_vm" {
  source            = "../../modules/pve_vm"
  count = 2
  node_name         = "zenith"
  vm_name           = "zenith-vm-${count.index + 1}"
  vm_cpu            = 2
  vm_ram            = 2048
  vm_vlan           = 66
}

output "vm_ip" {
  value = module.pve_vm[*].vm_ip
}