# Terraform – Kubernetes VMs

Provisions the Kubernetes node VMs on Proxmox for the homelab Kubernetes cluster.

## Overview

This Terraform project clones the `ubuntu-noble-cloud` template into virtual machines
on the proxmox nodes, following a capacity-aware placement algorithm:

1. **Control plane (master)** VMs are spread one per node, on the nodes with the most
   free memory that still fit the role's `ram`.
2. **Pack roles (worker)** are water-filled over the remaining capacity, most-available
   node first, without a per-node limit.

Each VM is tagged with the environment (`vm_env`) and registered in a Terraform-backed
Ansible inventory (via the `ansible` provider), so the `k8s_node` playbook can target
them by role group.

## Placement details

- Online Proxmox nodes are ordered by available memory (most available first, node name
  as tie-break).
- The control-plane role must fit entirely on distinct nodes with `free_mib >= ram`.
- Workers are packed into residual capacity (`free_mib - ram_per_cp_vm_on_node`),
  again most-available first.
- Naming: `kub-<env>-m<NN>` for masters and `kub-<env>-w<NN>` for workers, e.g.
  `kub-prod-m01`, `kub-prod-w01`.

Deployment is blocked by `check` blocks when the fleet cannot be placed:

- no online node is available,
- not enough nodes have the free memory required for the control-plane role,
- residual capacity cannot fit all worker VMs.

## Prerequisites

- Proxmox with:
  - a cloneable template named `ubuntu-noble-cloud` (from the `pve_vm` module),
  - a `ceph-workload` datastore,
  - VLAN bridge `vlan<id>` (default `vlan66`),
  - an API token and an SSH user/password with rights to create VMs on the nodes.
- Terraform with the `bpg/proxmox` and `ansible/ansible` providers (init downloads them).

## Input variables

| Variable                     | Type     | Required | Default                      | Description                                        |
| ---------------------------- | -------- | -------- | ---------------------------- | -------------------------------------------------- |
| `proxmox_endpoint`           | string   | yes      | –                            | Proxmox API URL                                    |
| `proxmox_api_token`          | string   | yes      | –                            | Proxmox API token (secret)                         |
| `proxmox_ssh_username`       | string   | yes      | –                            | Proxmox SSH user for placement (secret)            |
| `proxmox_ssh_password`       | string   | yes      | –                            | Proxmox SSH password (secret)                      |
| `vm_env`                     | string   | no       | `"prod"`                     | Environment, part of the VM name and tags          |
| `master_count`               | number   | no       | `null` → `vm_attr` default   | Number of master VMs                               |
| `master_cpu`                 | number   | no       | `null` → `vm_attr` default   | vCPU cores for masters                             |
| `master_ram`                 | number   | no       | `null` → `vm_attr` default   | Master RAM in **GiB** (converted to MiB internally)|
| `master_vlan`                | number   | no       | `null` → `vm_attr` default   | VLAN for masters                                   |
| `worker_count`               | number   | no       | `null` → `vm_attr` default   | Number of worker VMs                               |
| `worker_cpu`                 | number   | no       | `null` → `vm_attr` default   | vCPU cores for workers                             |
| `worker_ram`                 | number   | no       | `null` → `vm_attr` default   | Worker RAM in **GiB**                              |
| `worker_vlan`                | number   | no       | `null` → `vm_attr` default   | VLAN for workers                                   |
| `vm_attr`                    | map(… )  | no       | see below                    | Full per-role VM defaults                          |

The `vm_attr` map holds the fallback attributes used when the corresponding
`master_*`/`worker_*` override is `null`:

```hcl
vm_attr = {
  master = { ram = 2048, cpu = 2, vlan = 66, count = 3 }
  worker = { ram = 4096, cpu = 2, vlan = 66, count = 3 }
}
```

> `ram` values inside `vm_attr` are MiB; the `master_ram` / `worker_ram` overrides are
> set in GiB and converted internally (`× 1024`). The placement math always works in MiB.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

The `vm_ip` output maps VM name to assigned IP and feeds the Ansible inventory
(`inventories/`) of the `k8s_node` playbook.

## File reference

| File         | Purpose                                                   |
| ------------ | --------------------------------------------------------- |
| `main.tf`    | Placement algorithm, `pve_vm` module wiring, checks       |
| `variables.tf` | Clusters, Proxmox credentials, per-role defaults/overrides |
| `provider.tf`  | `proxmox` and `ansible` provider configuration          |