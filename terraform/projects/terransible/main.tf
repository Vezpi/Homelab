module "pve_vm" {
  source            = "../../modules/pve_vm"
  node_name         = "zenith"
  vm_name           = "zenith-vm"
  vm_cpu            = 2
  vm_ram            = 2048
  vm_vlan           = 66
}

output "vm_ip" {
  value = module.pve_vm.vm_ip
}

resource "ansible_group" "servers" {
  name = "servers"
}
resource "ansible_host" "vm" {
  name = "zenith-vm.lab.vezpi.me"
  groups = ["servers"]
  variables = {
    ansible_host                 =  module.pve_vm.vm_ip
  }
}

