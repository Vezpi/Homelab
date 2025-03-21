data "proxmox_virtual_environment_vms" "template" {
  filter {
      name   = "name"
      values = ["ubuntu-cloud"]
    }
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "zenith"
  source_raw {
    file_name = "simple_vm.cloud-config.yaml"
    data = <<-EOF
    #cloud-config
    hostname: simple-vm
    packages:
      - qemu-guest-agent
    users:
      - default
      - name: vez
        groups: sudo
        shell: /bin/bash
        ssh-authorized-keys:
          - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID62LmYRu1rDUha3timAIcA39LtcIOny1iAgFLnxoBxm vez@bastion"
        sudo: ALL=(ALL) NOPASSWD:ALL
    runcmd:
      - systemctl enable --now qemu-guest-agent 
    EOF
  }
}

resource "proxmox_virtual_environment_vm" "simple_vm" {
  name      = "simple-vm"
  node_name = "zenith"
  tags      = ["test"]
  agent {
    enabled = true
  }
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
    interface = "scsi0"
    size = 4
  }
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
    datastore_id         = "ceph-workload"
    interface            = "scsi1"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
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
