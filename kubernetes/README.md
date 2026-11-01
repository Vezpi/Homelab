# Kubernetes

## Overview

The lab inventory records six Kubernetes VMs on Proxmox: three control-plane nodes with stacked etcd and three workers. Kubernetes and Cilium are deployed, with worker BGP sessions to OPNsense recorded as established. No application workloads are deployed. This describes the documented state, not a live verification.

Terraform provisions the VMs, Ansible prepares the nodes, and bootstrap and initial component installation are manual. Background: [migration roadmap](https://blog.vezpi.com/en/post/roadmap-migrate-docker-applications-kubernetes/).

## Prerequisites

1. Provision the VMs with the [Terraform Kubernetes VMs documentation](../terraform/projects/kubernetes_vms/README.md).
2. Prepare all nodes with the [Ansible Kubernetes nodes documentation](../ansible/kubernetes/README.md). It configures swap, kernel settings, containerd, Kubernetes packages and the host firewall, but does not run `kubeadm init` or `kubeadm join`. Review the [Ansible defaults](../ansible/kubernetes/roles/k8s_node/defaults/main.yml) and adapt inventory paths and firewall ranges, including Cilium and BGP traffic.
3. Provide working node DNS and a stable API DNS endpoint on TCP port `6443`; the lab uses HAProxy on OPNsense across the control-plane nodes.
4. Install `kubectl` and the Cilium CLI on the administration machine, and check the intended cluster context. Keep credentials, kubeconfigs, join tokens and Terraform state out of Git.

Walkthrough: [Automating Kubernetes VM Deployment with Terraform and Ansible](https://blog.vezpi.com/en/post/automate-kubernetes-vms-terraform-ansible/).

## Cluster bootstrap: kubeadm

For a **new, prepared cluster**, initialize the first control-plane node with the target API DNS name and a non-overlapping pod CIDR:

```text
sudo kubeadm init \
  --control-plane-endpoint "<API_DNS>:6443" \
  --upload-certs \
  --pod-network-cidr=<POD_CIDR>
```

Configure `kubectl` using the generated admin kubeconfig. Join the remaining nodes with freshly generated commands: include `--control-plane` and `--certificate-key` for additional control planes, but not workers. Install Cilium below; nodes can remain `NotReady` until the CNI works.

Walkthrough: [Create a Highly Available Kubernetes Cluster with kubeadm on VMs](https://blog.vezpi.com/en/post/create-manual-kubernetes-cluster-kubeadm/). Its names, versions and firewall shortcuts are historical; use the Ansible preparation above rather than disabling the firewall.

**Installation caveat:** these historical commands are not a tested, reproducible rebuild procedure or instructions to reinstall the existing cluster. Exact Kubernetes package builds are unpinned; the historical CLI installer uses a moving `stable.txt`, and `cilium install` omits `--version`.

## Networking: Cilium

### CNI and pod connectivity

Cilium provides pod networking. The [bootstrap walkthrough](https://blog.vezpi.com/en/post/create-manual-kubernetes-cluster-kubeadm/) covers its checksum-verified, architecture-specific CLI download and connectivity testing; it predates this cluster's BGP setup.

The recorded fresh-cluster installation enables the BGP control plane:

```bash
cilium install --set bgpControlPlane.enabled=true
cilium status --wait
kubectl get nodes
```

Check for healthy Cilium components and all six nodes `Ready`. The optional `cilium connectivity test` exercises pod networking and DNS but creates temporary workloads; run only with approval and account for cleanup.

### BGP

Cilium peers with OPNsense FRR to advertise service `LoadBalancerIP` addresses. The recorded configuration uses `CiliumBGPPeerConfig` for peer settings and advertisement selection, `CiliumBGPClusterConfig` for worker selection and peering, and `CiliumBGPAdvertisement` for service advertisements.

The setup pairs FRR/BGP and firewall access on OPNsense with worker labels and matching peer settings and advertisement labels. Check sessions with `cilium bgp peers`; worker sessions are recorded as established, but that alone does not prove LoadBalancer address allocation, advertisement or reachability.

**BGP service exposure: ongoing.**
