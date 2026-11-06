# Semaphore single Proxmox VM

`ansible/proxmox/provision_vm.yml` clones one existing cloud-init-ready QEMU template, configures CPU, RAM, network, cloud-init user/key and disk while stopped, then starts it. This is one-shot provisioning, not reconciliation; no Terraform state, SSH, guest readiness check, or automatic deletion.

## Runner and fixed configuration

Create an Ansible task template in Semaphore pointing to `ansible/proxmox/provision_vm.yml` and a localhost inventory (`localhost ansible_connection=local`). The runner needs API reachability and a supported Python environment. Install Ansible Core, Python dependencies and the pinned real collection in that environment:

```sh
python3 -m pip install ansible-core -r ansible/proxmox/requirements.txt
ansible-galaxy collection install -r ansible/proxmox/requirements.yml
```

Assign a Semaphore Variable Group to the template. Put `proxmox_api_token_id` (full `user@realm!token` identifier) and `proxmox_api_token_secret` in the group's **Secrets** tab. The playbook splits the full token identifier into the module's `api_user=user@realm` and `api_token_id=token`. Do not expose these as survey inputs or commit them. Restrict token permissions and template launch access. API tasks use `no_log`; avoid verbose secret logging. TLS verification is enabled; trust the Proxmox CA in the runner. Never disable TLS verification.

Set these **fixed, non-survey** values in the Variable Group JSON, using inventory-approved choices (the placeholders below are not deployment values):

```json
{
  "proxmox_api_host": "pve.example.invalid",
  "proxmox_node": "example-node",
  "vm_template_id": 900,
  "vm_storage": "example-storage",
  "vm_user": "example-user",
  "vm_ssh_public_key": "ssh-ed25519 AAAAexamplePublicKey replace-with-your-own-public-key"
}
```

`proxmox_api_host` is a hostname, not a URL. `proxmox_api_port` defaults to 8006 and can be fixed in the group if different. `vm_ipconfig0` defaults to `ip=dhcp` and can be fixed in the group if an approved static configuration is required. `vm_template_id` must refer to a QEMU template on `proxmox_node`, with a bootable `scsi0` and `scsi1` cloud-init drive; `vm_storage` is the full-clone destination. The admin user and SSH **public** key are fixed configuration, not survey prompts. Never put a private key in `vm_ssh_public_key`.

## Survey: exactly five inputs

Map the Semaphore labels to these Ansible variable names; only hostname is required without a default:

| Survey label | Variable | Default | Meaning |
| --- | --- | --- | --- |
| Hostname | `vm_hostname` | required | New, unique VM name / hostname |
| CPU | `vm_cpu` | `1` | Cores |
| RAM (GiB) | `vm_ram_gib` | `2` | GiB; multiplied by 1024 for Proxmox memory in MiB |
| Disk size (GiB) | `vm_disk_gib` | `4` | Absolute requested `scsi0` size in GiB, not an increment |
| VLAN | `vm_vlan` | `vlan66` | Existing Proxmox VNet/bridge identifier used as `net0` bridge |

These CPU, RAM and disk defaults come from `terraform/projects/simple-vm/variables.tf` (`vm_cpu=1`, `vm_ram=2048` MB) and `terraform/projects/simple-vm/main.tf` (`disk.size=4` GB). Here 2048 MiB / 1024 = 2 GiB, and the playbook sends `2 * 1024 = 2048` MiB. Terraform's `vm_name` has no default. Its `vm_vlan=66` is interpolated into `bridge = "vlan${var.vm_vlan}"`; therefore `vlan66` is a bridge/VNet name, **not** a numeric VLAN tag to set on a separate bridge. The explicitly requested survey default is the literal `vlan66`. Do not supply an unapproved bridge name. The requested disk cannot be smaller than the template's `scsi0`.

Non-secret example survey JSON:

```json
{"vm_hostname":"example-vm","vm_cpu":1,"vm_ram_gib":2,"vm_disk_gib":4,"vm_vlan":"vlan66"}
```

For manual invocation, store fixed and survey non-secret variables in local JSON files outside this public repository and token variables in an encrypted Ansible Vault file outside it. Do not place credentials on the command line:

```sh
ansible-playbook -i localhost, -c local ansible/proxmox/provision_vm.yml \
  -e @/path/to/fixed-config.json -e @/path/to/survey.json \
  -e @/path/to/encrypted-token.yml --ask-vault-pass
```

The Terraform project additionally uploads custom cloud-config (packages, guest agent, sudo and reboot), enables the agent, and specifies BIOS/machine and other settings. This playbook does **not** reproduce those customizations. Verify that the chosen template supplies everything required before launch.

## Allocation, failures and rollback

The playbook first rejects an existing cluster-wide VM name. The pinned `community.proxmox.proxmox_kvm` clone module fetches the next free cluster VMID using Proxmox `/cluster/nextid` when `newid` is omitted, rejects an occupied ID, and returns the allocated `vmid`. The playbook checks `changed` and a valid returned VMID before configuring it; API allocation/clone failures stop execution. This is **not** a reservation or global uniqueness lock: simultaneous requests can race for a name or VMID, and VM names need not be unique in Proxmox. Do not launch duplicate names concurrently. If an API operation fails after clone, inspect the cluster and Semaphore log for the allocated ID before retrying; the VM may be partial, stopped or running. Do not blindly retry or delete it. Captain handles repair/removal manually.

API task completion or a powered-on VM does **not** prove guest cloud-init finished. Only Captain launches or reverses infrastructure changes. For code rollback, revert the scoped feature-branch commit; do not rewrite published branch history. Record any applied infrastructure change in the Obsidian vault.
