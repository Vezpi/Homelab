data "proxmox_virtual_environment_vms" "template" {
  filter {
    name   = "name"
    values = ["${var.vm_template}"]
  }
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name
  source_raw {
    file_name = "vm.cloud-config.yaml"
    data      = <<-EOF
    #cloud-config
    hostname: ${var.vm_name}
    package_update: true
    package_upgrade: true
    packages:
      - qemu-guest-agent
    users:
      - default
      - name: ${var.vm_user}
        groups: sudo
        shell: /bin/bash
        ssh-authorized-keys:
          - "${var.vm_user_sshkey}"
        sudo: ALL=(ALL) NOPASSWD:ALL
    runcmd:
      - systemctl enable qemu-guest-agent 
      - reboot
    EOF
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  tags      = var.vm_tags
  agent {
    enabled = true
  }
  stop_on_destroy = true
  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    node_name = data.proxmox_virtual_environment_vms.template.vms[0].node_name
  }
  bios    = var.vm_bios
  machine = var.vm_machine
  cpu {
    cores = var.vm_cpu
    type  = "host"
  }
  memory {
    dedicated = var.vm_ram
  }
  disk {
    datastore_id = var.node_datastore
    interface    = "scsi0"
    size         = 4
  }
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    datastore_id      = var.node_datastore
    interface         = "scsi1"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
  network_device {
    bridge  = "vmbr0"
    vlan_id = var.vm_vlan
  }
  operating_system {
    type = "l26"
  }
  vga {
    type = "std"
  }
}

output "vm_ip" {
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses[1][0]
  description = "VM IP"
}

