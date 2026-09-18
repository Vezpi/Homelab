# Ansible – Kubernetes nodes

Prepares the Kubernetes VM nodes provisioned by the
[`kubernetes_vms` Terraform project](../../terraform/projects/kubernetes_vms/).

## What it does

The `k8s_node` playbook configures each node for `kubeadm`/`kubelet`:

1. **System** – disables swap (runtime + fstab), loads `overlay` and `br_netfilter`,
   persists kernel modules, applies the Kubernetes `sysctl` settings.
2. **Packages** – installs prerequisites, adds the official Kubernetes apt repo/key,
   installs and holds `kubeadm` and `kubelet`.
3. **containerd** – installs it, generates the default config, enables the
   `SystemdCgroup` driver, starts and enables the service.
4. **Firewall** – configures UFW per role: SSH + common Kubernetes ports from the admin
   subnet, control-plane ports (`2379:2380`, `10257`, `10259`) on masters, worker ports
   (`10256`, `30000:32767`) on workers, default deny incoming.

Group membership (who is a `master` / `worker`) is resolved from the Terraform inventory,
so the role-specific firewall rules apply automatically.

> Cluster bootstrap (`kubeadm init` / `kubeadm join`) is **not** part of this playbook
> and is done manually per the migration roadmap.

## Inventory

The inventory is generated from Terraform state via the `cloud.terraform` inventory
plugin:

```yaml
# inventories/tf_k8s_vms.yml
---
plugin: cloud.terraform.terraform_provider
project_path:
  - /tmp/semaphore/project_1/repository_1_template_7/terraform/projects/kubernetes_vms
```

> The `project_path` is a Semaphore runtime checkout path. If you run locally, point it
> at your own `terraform/projects/kubernetes_vms` directory. The same `ansible` provider
> that writes the inventory is used by Terraform, so hosts/groups are always in sync with
> the applied VMs.

## Requirements

Install the collections referenced by `collections/requirements.yml`:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

- `cloud.terraform` – Terraform inventory plugin
- `community.general` – `ufw` module

## Usage

```bash
# Connectivity check
ansible-playbook -i inventories/tf_k8s_vms.yml ping.yml

# Prepare all Kubernetes nodes
ansible-playbook -i inventories/tf_k8s_vms.yml k8s_node.yml
```

Both playbooks target `all`; the inventory plugin runs from the Terraform project path.

## Role variables

Defined in `roles/k8s_node/defaults/main.yml` (override as needed):

| Variable                        | Default                      | Description                            |
| ------------------------------- | ---------------------------- | -------------------------------------- |
| `k8s_version`                   | `1.37`                       | Kubernetes minor version               |
| `k8s_repo`                      | `pkgs.k8s.io` core v<ver>    | Kubernetes apt repository              |
| `k8s_repo_key`                  | matching `Release.key` URL   | Repository signing key                 |
| `k8s_packages`                  | `kubelet`, `kubeadm`         | Packages installed and held            |
| `k8s_prerequisite_packages`     | `apt-transport-https`, `ca-certificates`, `curl`, `gnupg` | Build deps for the repo   |
| `k8s_firewall_admin_subnet`     | `192.168.66.0/24`            | Subnet allowed through UFW             |
| `k8s_firewall_ssh_port`         | `22`                         | SSH port                               |
| `k8s_firewall_common_ports`     | `6443`, `10250`              | Ports open on all nodes                |
| `k8s_firewall_master_ports`     | `2379:2380`, `10257`, `10259` | Ports open on masters                |
| `k8s_firewall_worker_ports`     | `10256`, `30000:32767`       | Ports open on workers                  |

## File reference

| Path                                     | Purpose                              |
| ---------------------------------------- | ------------------------------------ |
| `k8s_node.yml`                           | Main playbook (role `k8s_node`)      |
| `ping.yml`                               | Connectivity smoke-test playbook     |
| `inventories/tf_k8s_vms.yml`             | Terraform-backed inventory           |
| `collections/requirements.yml`           | Required Ansible collections         |
| `roles/k8s_node/tasks/main.yml`          | Task dispatcher                      |
| `roles/k8s_node/tasks/system.yml`        | Swap, kernel modules, sysctl         |
| `roles/k8s_node/tasks/packages.yml`      | Kubernetes repo + kubeadm/kubelet    |
| `roles/k8s_node/tasks/containerd.yml`    | containerd install/config            |
| `roles/k8s_node/tasks/firewall.yml`      | Per-role UFW rules                   |
| `roles/k8s_node/defaults/main.yml`       | Role defaults                        |