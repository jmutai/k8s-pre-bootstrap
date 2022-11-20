# k8s_setup project

## Contents

- [k8s_setup project](#k8s-setup-project)
  - [Quick start](#quick-start)
  - [Supported Linux distribution (distros)](#supported-linux-distribution--distros-)
  - [Project system requirements](#project-system-requirements)
  - [Main ideas (basic concept)](#main-ideas--basic-concept-)
  - [Playbooks](#playbooks)
  - [Stuff playbooks (in folder stuff)](#stuff-playbooks--in-folder-stuff-)
  - [WARNINGS](#warnings)
  - [How to use this project](#how-to-use-this-project)
    - [Install Git and Ansible](#install-git-and-ansible)
    - [Git clone project](#git-clone-project)
    - [Setting up ansible](#setting-up-ansible)
    - [Generate SSH key of any type](#generate-ssh-key-of-any-type)
    - [Configure inventory for the stand](#configure-inventory-for-the-stand)
    - [Deploy SSH public key to remote hosts (setup SSH passwordless authentication) and visudo user](#deploy-ssh-public-key-to-remote-hosts--setup-ssh-passwordless-authentication--and-visudo-user)
    - [(Optional) Verify the MAC address and product_uuid are unique for every node](#-optional--verify-the-mac-address-and-product-uuid-are-unique-for-every-node)
    - [Running playbook k8s_setup.yml](#running-playbook-k8s-setupyml)
    - [Cluster initialization on one master](#cluster-initialization-on-one-master)
    - [Copy commands for join masters and workers](#copy-commands-for-join-masters-and-workers)
    - [(Optional) Join masters](#-optional--join-masters)
    - [Join workers](#join-workers)
  - [Clean up (if something went wrong while creating the cluster)](#clean-up--if-something-went-wrong-while-creating-the-cluster-)

<br/>
<br/>

This project contains several playbooks that help you automate setting up a Kubernetes Cluster on VMs or bare-metal servers. `kubeadm` deployment method is used [Bootstrapping clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/).  

<br/>

## Quick start

Follow the steps from point [How to use this project](#how-to-use-this-project) in sequence.  

## Supported Linux distribution (distros)

The playbook supports any Linux distributions, since you can add your own tasklist for each distribution or family of distributions. At the moment, the playbook contains tasklists for CentOS 7, CentOS 8, Debian, Ubuntu. The playbook was previously tested on CentOS 7 but has changed a lot since then. The current version has been tested on Astra Linux 1.7 (similar to Debian 10).  

## Project system requirements

- Ansible version `2.9+`.  
- On all servers, a sudo user must be created under which the SSH connection occurs. You yourself can automate the process of creating such a user if it does not exist. When cloning virtual machines from a template, there is usually such an administrator user already there.  

## Main ideas (basic concept)

- All variables and list of hosts are collected in one file inventory (see example `inventory\example.standXXX.yml`).  
- Main playbook `k8s_setup.yml` is divided into three stages (each of which is represented by a separate role): `OS prepare`, `Kubernetes setup` and `HA setup`. Each of which can be performed separately (or not performed). This can be regulated by variables in inventory (see example `inventory\example.standXXX.yml`) and tags.  
- Each step in each of the three stages can be performed separately (or not performed). This can be regulated by variables in inventory (see example `inventory\example.standXXX.yml`) and tags.  
- Stage `OS prepare` helps to prepare the server operating system and can be used not only for servers intended for the Kubernetes, but also for auxiliary servers (group `others`) included in this stand, for example, DNS, NTP, etc.  
- Stage `Kubernetes Setup` OS prepare for K8S, setup container runtime and install k8s packages.  
- Stage `HA Setup` installation and configuration of keepalived and haproxy.  
- Support for various Linux distributions is implemented by adding a tasklists whose names are given by ansible facts `os_distrib_version`, `os_family_version`, `os_distrib` and `os_family` (see `k8s_setup.yml`). **Attention!** Some tasks for some Linux distributions are not currently implemented, for example `Config Access Control system (SELinux, AppArmor, parsec)`, and are left as a stub (see `roles/os-prepare/tasks/config_ac_astralinux.yml`).  

## Playbooks

- **k8s_setup.yml**             - Main playbook for OS prepare, Kubernetes setup and HA setup.  
- **deploy_ssh_public_key.yml** - Set up passwordless access via SSH.  
- **k8s_init_cluster.yml**      - K8s cluster initialization (kubeadm init).  
- **k8s_join_masters.yml**      - Join masters (for HA).  
- **k8s_join_workers.yml**      - Join workers.  
- **k8s_delete_cluster.yml**    - Delete k8s cluster (HA is not deleted).  

## Stuff playbooks (in folder stuff)

- **check_unique_uuid.yml** - [Verify the MAC address and product_uuid are unique for every node](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#verify-mac-address). Needed for cloned VMs.

## WARNINGS

- At stage `Prepare OS`, the reboot is performed twice, so it is better to execute the playbook from a separate server (administrator's computer), otherwise the playbook execution will be interrupted.  
- Step `config_os_network` assumes that the network in the OS is managed by the `networking` and `resolvconf` services. If the network settings are managed by the `NetworkManager` service, disable this step.  
- Virtual IP (VIP) must be recognized via DNS or be included in the `/etc/hosts` file.  

## How to use this project

The project requires Ansible, which can be installed both on one of the computers of the current stand and a completely separate computer that has network access to all computers of the stand (admin's computer).

### Install Git and Ansible

Installation is different for different Linux distributions, so see the documentation for those software products:  

- [Installing Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Installing Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

**Attention!** For ansible you will need to install additional collections.

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
```

### Git clone project

```bash
cd ~
git clone https://github.com/MinistrBob/k8s_setup.git
cd k8s_setup
```

### Setting up ansible

You can change ansible settings in ansible.cfg file. By default, the settings are optimal.  

```bash
cp ansible.cfg.example ansible.cfg
nano ansible.cfg
```

If you have one stand and one inventory then you can define an `inventory` variable so you don't have to specify it every time.

```bash
inventory = inventory/standXXX.yml
```

### Generate SSH key of any type

```bash
ssh-keygen -t ed25519
```

### Configure inventory for the stand

All variables in `stand.yml.example` have comments explaining the purpose of the variables.  
The name of the stand (`stand.yml`) can be anything. It is possible to keep several configuration files here for several stands.  
**Attention!** Two variables are required for SSH options: `ansible_user` and `ansible_private_key_file` (see `inventory/stand.yml.example`).  
The project uses three groups:

- **kube** - All servers for the cluster Kubernetes (masters and workers and others).  
- **kube_masters** - Servers for master components Kubernetes. There may be one. For HA cofiguration it is better to have three master servers.  
- **auxiliary** - Auxiliary stand servers that are not included in the Kubernetes cluster. For them, only the first stage `OS prepare` is performed, for example, DNS, NTP, etc.  

```bash
cp inventory/stand.yml.example inventory/standXXX.yml
nano inventory/standXXX.yml
```

### Deploy SSH public key to remote hosts (setup SSH passwordless authentication) and visudo user

(Optional) You can check SSH connection is on one of host manualy to make sure that the ssh connection is established at all.

```bash
ssh -i ~/.ssh/id_ed25519 user1@pp-ceph-osd-01
```

Playbook executed with password.

```bash
ansible-playbook -i inventory/standXXX.yml deploy_ssh_public_key.yml --ask-pass
```

If on the remote server the sudo command asks for a password, then you need to specify it too.  
Playbook executed with password and sudo password.

```bash
ansible-playbook -i inventory/standXXX.yml deploy_ssh_public_key.yml --ask-pass --ask-become-pass
```

If even after specifying the correct password you get error `Permission denied (publickey,password)` then you can try to use module `paramiko` instead of `openssh` to connect SSH.  
In the future, after the public key is installed, `paramiko` does not need to be used.

```bash
ansible-playbook -i inventory/standXXX.yml deploy_ssh_public_key.yml -c paramiko --ask-pass
```

### (Optional) Verify the MAC address and product_uuid are unique for every node

Playbook **check_unique_uuid.yml** show MAC addresses and UUID. If VMs were cloned, then they may have not uniqu MAC and UUID. **You must visually verify that everything is unique**.  
**NOTE**: VMware ESXi changes the MAC address during virtual machine cloning.

```bash
ansible-playbook stuff/check_unique_uuid.yml
```

### Running playbook k8s_setup.yml

This playbook does all the main work and fully prepares the cluster before it is initialized.

```bash
ansible-playbook -i inventory/standXXX.yml k8s_setup.yml
```

### Cluster initialization on one master

Examples of three different ways to initialize a cluster. Here extra-vars parameter `mc` is the cluster initialization command.

```bash
ansible-playbook -i inventory/standXXX.yml k8s_init_cluster.yml --extra-vars "mc='kubeadm init'"
ansible-playbook -i inventory/standXXX.yml k8s_init_cluster.yml --extra-vars "mc='kubeadm init --pod-network-cidr=10.244.0.0/16'"
ansible-playbook -i inventory/standXXX.yml k8s_init_cluster.yml --extra-vars "mc='kubeadm init --control-plane-endpoint pp-vip-k8s.mydomen.com:8443 --upload-certs --pod-network-cidr 10.244.0.0/16'"
```

During the initialization process, two log files will be created:

- `cluster_init.log` - Cluster initialization log and command for join masters and workers.
- `install_calico.log` - Pod network installation log.

To check the cluster you can execute (this is as example):

```bash
$ kubectl get nodes -o wide
NAME              STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
pp-mk8s-01   Ready    master   39m   v1.19.2   10.147.245.25   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   docker://19.3.11

$ kubectl -n kube-system get pod
NAME                                      READY   STATUS    RESTARTS   AGE
calico-kube-controllers-c9784d67d-98dx8   1/1     Running   0          39m
calico-node-ml9gv                         1/1     Running   0          39m
coredns-f9fd979d6-jwdnc                   1/1     Running   0          39m
coredns-f9fd979d6-wgrqh                   1/1     Running   0          39m
etcd-rtz-ppd-mk8s-01                      1/1     Running   0          39m
kube-apiserver-rtz-ppd-mk8s-01            1/1     Running   0          39m
kube-controller-manager-rtz-ppd-mk8s-01   1/1     Running   0          39m
kube-proxy-z4qvt                          1/1     Running   0          39m
kube-scheduler-rtz-ppd-mk8s-01            1/1     Running   0          39m
```

### Copy commands for join masters and workers

Copy command for join masters and workers from screnn or file `cluster_init.log` to `vars/join_commands.yml`.

### (Optional) Join masters

If you are setting high availability (HA) configuration then you need to join other masters to cluster.

```bash
ansible-playbook -i inventory/standXXX.yml k8s_join_masters.yml
```

### Join workers

Join all workers servers to cluster.

```bash
ansible-playbook -i inventory/standXXX.yml k8s_join_workers.yml
```

You can check on the master server.

```bash
kubectl get nodes
```

## Clean up (if something went wrong while creating the cluster)

See [Clean up](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down)

```bash
ansible-playbook -i inventory/standXXX.yml k8s_delete_cluster.yml
```

If you have a need to clean the iptavles (you can not do this).  

```bash
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
sudo iptables -L -n -t nat
```
