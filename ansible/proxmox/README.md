# Provision one Proxmox VM with Semaphore

Run `ansible/proxmox/provision_vm.yml` as a Semaphore Ansible task with inventory `localhost ansible_connection=local`. It clones one cloud-init template, configures the new VM before boot, then connects to the guest by FQDN.

## Prerequisites

- The template needs a bootable `scsi0`, a `scsi1` cloud-init drive, Python 3, `cloud-init`, `timeout`, SSH and network access. It does not need the QEMU guest agent enabled.
- The guest needs `timedatectl`, `tzdata`, apt access and noninteractive sudo for `vm_user` to set its timezone and install/start the agent.
- The Semaphore runner must trust the Proxmox CA and have a verified guest SSH host key in `known_hosts`. Do not disable TLS or SSH host-key verification. Confirm the DNS record belongs to the new VM before connecting; a stale record could point to another host.
- Select an SSH Key Store **user credential on the task inventory** matching an authorized public key for `vm_user`. Check that the same invocation makes this credential available to the dynamically added guest in your installed Semaphore version. The Proxmox API token is separate.
- The Semaphore image installs `proxmoxer>=2.3,<3` and `requests>=2.31,<3` from `docker/semaphore/requirements.txt` on startup (mounted at `/etc/semaphore/requirements.txt`). Semaphore installs `ansible/proxmox/requirements.yml` (`community.proxmox:2.0.0`) unless **Skip Galaxy install** is enabled.

## Semaphore variables

Put these fixed values in a Variable Group:

| Variable | Value |
| --- | --- |
| `proxmox_api_host` | Hostname, not a URL |
| `vm_template_id`, `vm_storage`, `vm_user` | Template, destination storage and guest user |
| `vm_ssh_public_key` | One or more complete public keys, separated by newlines; include the key matching the selected SSH credential |
| `proxmox_api_port` | Optional; defaults to `8006` |
| `vm_ipconfig0` | Optional; defaults to `ip=dhcp` |

Put `proxmox_api_token_id` (full `user@realm!token`) and `proxmox_api_token_secret` in the Variable Group's **Secrets** tab, not the survey.

Survey inputs:

| Variable | Default |
| --- | --- |
| `vm_hostname` | Required unique short DNS label (no dots) |
| `vm_cpu` | `1` core |
| `vm_ram_gib` | `2` GiB |
| `vm_disk_gib` | `4` GiB, absolute disk size |
| `vm_vlan` | `vlan66` bridge/VNet name |

Only `vlan66` maps to a DNS suffix (`lab.vezpi.com`); other VLANs fail before cloning. DHCP/DNS must publish `<hostname>.lab.vezpi.com` for that VNet.

## What happens

1. The playbook rejects an invalid or existing hostname, then finds the template's current node and clones it. It enables the clone's virtio guest-agent channel before first boot, regardless of template configuration.
2. It waits for DNS, port 22, an Ansible connection and cloud-init. Cloud-init exit code `0` is accepted; degraded exit code `2` is accepted with a warning. Other codes, incomplete status and timeouts fail.
3. On the guest it sets the display timezone to `Europe/Paris` (CET/CEST), installs `qemu-guest-agent` and starts its device-activated service. It does not change RTC/NTP, manually enable the static unit, configure sudo or reboot.

A failure leaves the new VM intact for inspection. Playbook success does **not** prove agent communication: on the VM's actual Proxmox node, run `qm agent <NEW_VMID> ping`. A successful exit with no error is sufficient, even if the response is empty.
