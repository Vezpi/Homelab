
resource "proxmox_vm_qemu" "cloudinit-test" {
  name = "terraform-test-vm"
  desc = "A test for using terraform and cloudinit"
  tags = "test"

  target_node = "zenith"

  clone = "ubuntu-cloud"

  agent = 0

  os_type  = "cloud-init"
  bios     = "ovmf"

  cores    = 2
  sockets  = 1
  vcpus    = 0
  cpu_type = "host"
  memory   = 2048

  scsihw   = "virtio-scsi-pci"
  disks {
    scsi {
      scsi0 {
        disk {
          storage = "ceph-workload"
          size    = "4G"
        }
      }
      scsi1 {
        cloudinit {
          storage = "ceph-workload"
        }
      }
    }

  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 66
  }
  
  vga {
    type = "std"
  }

  # Setup the disk
  

  # Setup the network interface and assign a vlan tag: 256
  

  # Setup the ip address using cloud-init.
  boot = "order=scsi0"
  # Keep in mind to use the CIDR notation for the ip.
  ipconfig0 = "ip=dhcp"
  ciuser = "vez"
  ciupgrade = true
  sshkeys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxWxrBF6W6N2ZrzoKhTwDTZ49tlYzvki+4naHjo8DhB vez-key"



}