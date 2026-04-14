## Role info

> This playbook is not for fully setting up a Kubernetes Cluster.

It only helps you automate the standard Kubernetes bootstrapping pre-reqs.

## Supported OS

**RedHat family:**
- Rocky Linux 9|10
- AlmaLinux 9|10
- CentOS Stream 9

**Debian family:**
- Ubuntu 24.04 LTS (Noble Numbat)
- Debian 13 (Trixie)
- Debian 12 (Bookworm)

## Required Ansible
Ansible version required `2.14+`

Install required collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Tasks in the role

This role contains tasks to:

- Install basic packages required
- Setup standard system requirements - Disable Swap, Modify sysctl, Disable SELinux (RedHat only)
- Automatically reboot if a kernel update was applied
- Install and configure a container runtime of your choice - containerd, CRI-O, or Docker (with cri-dockerd)
- Install the Kubernetes packages - kubelet, kubeadm and kubectl
- Hold Kubernetes packages to prevent accidental upgrades (Debian/Ubuntu)
- Configure firewall rules - firewalld on RedHat, ufw on Debian/Ubuntu (optional)

## How to use this role

- Clone the Project:

```bash
git clone https://github.com/jmutai/k8s-pre-bootstrap.git
cd k8s-pre-bootstrap
```

- Install Ansible collection dependencies:

```bash
ansible-galaxy collection install -r requirements.yml
```

- Update your inventory:

```bash
vim hosts
[k8snodes]
k8smaster01
k8smaster02
k8smaster03
k8snode01
k8snode02
k8snode03
```

- Update variables in playbook file:

```yaml
vim k8s-prep.yml
---
- name: Prepare Kubernetes Nodes for Cluster bootstrapping
  hosts: k8snodes
  become: yes
  become_method: sudo
  vars:
    k8s_version: "1.35"                                  # Kubernetes version to be installed
    selinux_state: permissive                            # SELinux state to be set on k8s nodes (RedHat only)
    timezone: "Africa/Nairobi"                           # Timezone to set on all nodes
    k8s_cni: calico                                      # calico, flannel
    container_runtime: containerd                        # docker, cri-o, containerd
    pod_network_cidr: "192.168.0.0/16"                   # Pod network CIDR
    configure_firewalld: false                           # true / false (enable firewall rules)
    # Docker proxy support
    setup_proxy: false                                   # Set to true to configure proxy
    proxy_server: "proxy.example.com:8080"               # Proxy server address and port
    docker_proxy_exclude: "localhost,127.0.0.1"          # Addresses to exclude from proxy
  roles:
    - kubernetes-bootstrap
```

If you are using non root remote user, then set username and enable sudo:

```yaml
become: yes
become_method: sudo
```

To enable proxy, set the value of `setup_proxy` to `true` and provide proxy details.

## Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `k8s_version` | `1.35` | Kubernetes minor version to install |
| `selinux_state` | `permissive` | SELinux state (RedHat only, ignored on Debian) |
| `timezone` | `Africa/Nairobi` | System timezone for all nodes |
| `k8s_cni` | `calico` | CNI plugin: `calico` or `flannel` |
| `container_runtime` | `containerd` | Runtime: `containerd`, `cri-o`, or `docker` |
| `pod_network_cidr` | `192.168.0.0/16` | Pod network CIDR |
| `configure_firewalld` | `false` | Enable firewall configuration |
| `setup_proxy` | `false` | Enable Docker proxy configuration |
| `proxy_server` | `proxy.example.com:8080` | Proxy server address |
| `docker_proxy_exclude` | `localhost,127.0.0.1` | Proxy exclusions |

## Running Playbook

Once all values are updated, you can then run the playbook against your nodes.

Check playbook syntax to ensure no errors:

```bash
ansible-playbook --syntax-check k8s-prep.yml -i hosts
```

Playbook executed as root user - with ssh key:

```bash
ansible-playbook -i hosts k8s-prep.yml
```

Playbook executed as sudo user - with password:

```bash
ansible-playbook -i hosts k8s-prep.yml --ask-pass --ask-become-pass
```

Playbook executed as sudo user - with ssh key and passwordless sudo:

```bash
ansible-playbook -i hosts k8s-prep.yml --become
```

### Firewall Configuration

**NOTE**: Firewall configuration is disabled by default (`configure_firewalld: false`). If enabled, a pattern in hostname is required for master and worker nodes. The role uses:
- **firewalld** on RedHat family
- **ufw** on Debian/Ubuntu family

Hostnames must contain `master` for control plane nodes and `node` or `worker` for worker nodes. Example:

```
k8smaster01
k8smaster02
k8sworker01
k8sworker02
```

## Tested On

| OS | K8s Version | Container Runtime | Result |
|----|------------|-------------------|--------|
| Rocky Linux 10.1 | v1.35.3 | containerd v2.2.2 | Pass |
| Ubuntu 24.04 LTS | v1.35.3 | containerd v2.2.2 | Pass |
| Debian 12 | v1.35.3 | containerd v2.2.2 | Pass |

Next: Bootstrap the K8s control plane - https://computingforgeeks.com/install-kubernetes-cluster-on-rocky-linux-with-kubeadm-crio/
