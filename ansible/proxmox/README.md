# Provision one Proxmox VM with Semaphore

Create an Ansible task template for `ansible/proxmox/provision_vm.yml` with a localhost inventory (`localhost ansible_connection=local`). It clones a cloud-init QEMU template, configures the VM and starts it.

The Semaphore server gets `proxmoxer>=2.3,<3` and `requests>=2.31,<3` from `docker/semaphore/requirements.txt` (mounted from `/appli/docker/semaphore/requirements.txt` to `/etc/semaphore/requirements.txt`); the image installs these on container startup, not merely on mount. Semaphore automatically installs the adjacent `ansible/proxmox/requirements.yml` (`community.proxmox:2.0.0`) unless **Skip Galaxy install** is enabled.

In a Semaphore Variable Group, set fixed `proxmox_api_host` (hostname, not URL), `proxmox_node`, `vm_template_id`, `vm_storage`, `vm_user`, and `vm_ssh_public_key` (public key only). Set `proxmox_api_token_id` (full `user@realm!token`) and `proxmox_api_token_secret` in the group's **Secrets** tab, not the survey. Optional fixed values: `proxmox_api_port` (default 8006) and `vm_ipconfig0` (default `ip=dhcp`). Trust the Proxmox CA in the runner; TLS verification stays enabled.

| Survey variable | Default |
| --- | --- |
| `vm_hostname` | Required; unique name |
| `vm_cpu` | `1` core |
| `vm_ram_gib` | `2` GiB |
| `vm_disk_gib` | `4` GiB, absolute disk size |
| `vm_vlan` | `vlan66` bridge/VNet name |

Use a template with bootable `scsi0` and a `scsi1` cloud-init drive; partial failures are not automatically deleted, and starting the VM does not guarantee guest cloud-init readiness.
