data "proxmox_virtual_environment_vms" "template" {
  filter {
      name   = "name"
      values = ["ubuntu-cloud"]
    }
}

# resource "proxmox_virtual_environment_file" "cloud_config" {
#   content_type = "snippets"
#   datastore_id = "local"
#   node_name    = "zenith"

#   source_raw {
#     data = <<-EOF
#     #cloud-config
#     hostname: simple-vm
#     packages:
#       - qemu-guest-agent
#     users:
#       - default
#       - name: vez
#         groups: sudo
#         shell: /bin/bash
#         ssh-authorized-keys:
#           - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxWxrBF6W6N2ZrzoKhTwDTZ49tlYzvki+4naHjo8DhB vez-key"
#         sudo: ALL=(ALL) NOPASSWD:ALL
#     EOF

#     file_name = "example.cloud-config.yaml"
#   }
# }

resource "proxmox_virtual_environment_vm" "simple_vm" {
  name      = "simple-vm"
  node_name = "zenith"
  tags      = ["test"]

  agent {
    enabled = false
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  
  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
  }

  bios = "ovmf"
  machine = "q35"

  cpu {
    cores = 2
    type = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "ceph-workload"
    #file_id      = proxmox_virtual_environment_download_file.latest_ubuntu_22_jammy_qcow2_img.id
    interface = "scsi0"
    size = 4
  }

  initialization {
    datastore_id         = "ceph-workload"
    interface            = "scsi1"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
     keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID62LmYRu1rDUha3timAIcA39LtcIOny1iAgFLnxoBxm vez@bastion"]
     username = "vez"
    }

    #user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  network_device {
    bridge = "vmbr0"
    vlan_id = 66
  }

  operating_system {
    type = "l26"
  }

  vga {
    type = "std"
  }

}
