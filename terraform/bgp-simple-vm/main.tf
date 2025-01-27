data "proxmox_virtual_environment_vms" "template" {
  filter {
      name   = "name"
      values = ["ubuntu-cloud"]
    }
}
resource "proxmox_virtual_environment_vm" "simple_vm" {
  name      = "simple-vm"
  node_name = "zenith"
  tags      = ["terraform", "test"]


  agent {
    enabled = false
  }
  # if agent is not enabled, the VM may not be able to shutdown properly, and may need to be forced off
  stop_on_destroy = true

  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = 2048
    floating  = 2048 # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = "ceph-workload"
    #file_id      = proxmox_virtual_environment_download_file.latest_ubuntu_22_jammy_qcow2_img.id
    interface = "scsi0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    #user_account {
    #  keys     = [trimspace(tls_private_key.ubuntu_vm_key.public_key_openssh)]
    #  password = random_password.ubuntu_vm_password.result
    #  username = "ubuntu"
    #}

    #user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }


}
