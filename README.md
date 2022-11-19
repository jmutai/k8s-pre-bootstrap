-- Проверить SSH соединение 
ssh worker@astra170-1.dmz.dear.com.ru

-- Запуск с паролем
ansible-playbook -i inventory/stand.yml send_public_key.yml -b --ask-pass
-- Эта ошибка может значить что пароль не правильный
Failed to connect to the host via ssh: worker@astra170-1.dmz.dear.com.ru: Permission denied (publickey,password).
-- Всё равно получаю эту ошибку, тогда запуск через paramiko
ansible-playbook -i inventory/stand.yml send_public_key.yml -c paramiko -b --ask-pass
-- Проверка доступности всех хостов
ansible -i inventory/stand.yml all -m ping

ERROR! couldn't resolve module/action 'community.general.modprobe'. This often indicates a misspelling, missing collection, or incorrect module path.
ansible-galaxy collection install community.general

ERROR! couldn't resolve module/action 'ansible.posix.sysctl'. This often indicates a misspelling, missing collection, or incorrect module path.
ansible-galaxy collection install ansible.posix

ansible-playbook -i inventory/stand.yml k8s_setup.yml
ansible-playbook -i inventory/stand.yml k8s_setup.yml --list-tasks
 



Предполагается что все хосты предназначены только для Kubernetes.

# confirm what task names would be run if I ran this command and said "just ntp tasks"
ansible-playbook -i production webservers.yml --tags ntp --list-tasks

# confirm what hostnames might be communicated with if I said "limit to boston"
ansible-playbook -i production webservers.yml --limit boston --list-hosts

tags: ver
tags: os_prep, kube_set, ha_set

tags1: pre_tasks, config_net, config_pm, set_proxy, remove_firewall, firewall, config_ac,  reboot, upgrade_os, install_pack, config_ntp, reboot
tags2: pre_setup, dis_swap, kernel_mod, etc_hosts, container, k8s_pack
tags3: firewall, 


# ---------------------------------------------------------------------

# k8s_setup project

This project contains several playbooks that help you automate setting up a Kubernetes Cluster on VMs or bare-metal servers. `kubeadm` deployment method is used [Bootstrapping clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/).  

## Quick start

Follow the steps from point [How to use this project](#how-to-use-this-project) in sequence.  

## Supported Linux distribution (distros)

The playbook supports any Linux distributions, since you can add your own tasklist for each distribution or family of distributions. At the moment, the playbook contains tasklists for CentOS 7, CentOS 8, Debian, Ubuntu. The playbook was previously tested on CentOS 7 but has changed a lot since then. The current version has been tested on Astra Linux 1.7 (similar to Debian 10).  

## Project system requirements

Ansible version `2.9+`.  

## Main ideas (basic concept)

- All variables and list of hosts are collected in one file inventory (see example `inventory\example.standXXX.yml`).  
- Main playbook `k8s_setup.yml` is divided into three stages (each of which is represented by a separate role): `OS prepare`, `Kubernetes setup` and `HA setup`. Each of which can be performed separately (or not performed). This can be regulated by variables in inventory (see example `inventory\example.standXXX.yml`) and tags.  
- Each step in each of the three stages can be performed separately (or not performed). This can be regulated by variables in inventory (see example `inventory\example.standXXX.yml`) and tags.  
- Stage `OS prepare` helps to prepare the server operating system and can be used not only for servers intended for the Kubernetes, but also for auxiliary servers (group `others`) included in this stand, for example, DNS, NTP, etc.  
- Stage `Kubernetes Setup` OS prepare for K8S, setup container runtime and install k8s packages.  
- Stage `HA Setup` installation and configuration of keepalived and haproxy.  
- Support for various Linux distributions is implemented by adding a tasklists whose names are given by ansible facts `os_distrib_version`, `os_family_version`, `os_distrib` and `os_family` (see `k8s_setup.yml`). **Attention!** Some tasks for some Linux distributions are not currently implemented, for example `Config Access Control system (SELinux, AppArmor, parsec)`, and are left as a stub (see `roles/os-prepare/tasks/config_ac_astralinux.yml`).  

## Main playbooks

- **k8s_setup.yml** - Main playbook for OS prepare, Kubernetes setup and HA setup.  
- **send_public_key.yml** - Set up passwordless access via SSH.  
- **k8s_init_cluster.yml** - K8s cluster initialization (kubeadm init).  
- **k8s_join_masters.yml** - Join masters (for HA).  
- **k8s_join_workers.yml** - Join workers.  
- **k8s_delete_cluster.yml** - Delete k8s cluster (HA is not deleted).  

## Stuff playbooks (in folder stuff)

- **check_unique_uuid.yml** - [Verify the MAC address and product_uuid are unique for every node](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#verify-mac-address). Needed for cloned VMs.

# How to use this project

The project requires Ansible, which can be installed both on one of the computers of the current stand and a completely separate computer that has network access to all computers of the stand (admin's computer).

## Install Git and Ansible

Installation is different for different Linux distributions, so see the documentation for those software products:  

- [Installing Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Installing Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

For ansible you will need to install additional collections.

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
```

## Git clone project

```bash
cd ~
git clone https://github.com/MinistrBob/k8s_setup.git
cd k8s_setup
```

## Setting up ansible

You can change ansible settings in ansible.cfg file. By default, the settings are optimal.  

```bash
cp ansible.cfg.example ansible.cfg
nano ansible.cfg
```

## Set up inventory for the stand

The name of the stand (`stand.yml`) can be anything. It is possible to keep several configuration files here for several stands.  
All variables have comments explaining the purpose of the variables.  
The project uses three groups:

- **kube** - All servers for the cluster Kubernetes (masters and workers and others).  
- **kube_masters** - Servers for master components Kubernetes. There may be one. For HA cofiguration it is better to have three master servers.  
- **auxiliary** - Auxiliary stand servers that are not included in the Kubernetes cluster. For them, only the first stage `OS prepare` is performed, for example, DNS, NTP, etc.  

```bash
cp inventory/stand.yml.example inventory/stand.yml
nano inventory/stand.yml
```

## Deploy the public key to remote hosts (setup passwordless authentication) and visudo current user

Generate SSH keys of any type.  

```bash
ssh-keygen -t ed25519
```

- Edit **send_public_key.yml**, insert instead of ```<sshkey>``` line with public key from ```/home/<user>/.ssh/id_rsa.pub```. You can see key ```cat /home/$USER/.ssh/id_rsa.pub```.

- Edit **send_public_key.yml**, insert instead of ```<username>``` user name (user under whom the installation is performed). 

- Deploy key with ansible
```
ansible-playbook send_public_key.yml -b --ask-pass
```
If you get the error "missing sudo password", try this
```
ansible-playbook send_public_key.yml -b --ask-pass -kK
```


### Verify the MAC address and product_uuid are unique for every node

Playbook **check_uniq.yml** show MAC addresses and UUID. If VMs were cloned, then they may have not uniqu MAC and UUID. **You must visually verify that everything is unique**.  
```
ansible-playbook check_uniq.yml
```

### Preliminary preparation infrastructure
  
- It is desirable that all servers distinguish each other by name. To do this, either you need to have a configured DNS or prepare files ```/etc/hosts``` and ```/etc/resolv.conf``` on the master and copy them to other servers using **net_config_copy.yml**.
- WARNING: Executed only for workers. You prepare configuration files on the Master, and then using ansible they are copied to the Workers.  
- WARNING: If you use Network Manager (in the CentOS 7 by default it that) to change the DNS settings, changing file ```/etc/resolv.conf``` is not enough, you need to change the network settings, for example in ```/etc/sysconfig/network-scripts/ifcfg-ens192```, otherwise the Network Manager will overwrite file ```/etc/resolv.conf``` when the OS reboots
```
ansible-playbook net_config_copy.yml
```

- If Internet works through a proxy, then you need configure `/etc/environment`, `/etc/yum.conf`, `/etc/profile.d/http_proxy.sh` files, and run command that copy this files to another servers.
- WARNING: Executed only for workers. You prepare configuration files on the Master, and then using ansible they are copied to the Workers.  
```
ansible-playbook proxy_settings_copy.yml
```
This is example files:  
```
# nano /etc/environment


https_proxy=http://10.1.113.15:1010/
http_proxy=http://10.1.113.15:1010/
no_proxy=localhost,127.0.0.0/8,::1,10.128.0.0/16,10.147.245.11,10.147.245.12,10.147.245.13,10.147.245.14,10.147.245.15,10.147.245.16,10.147.245.17,10.147.245.18,10.147.245.19,10.147.245.20,10.147.245.21,10.147.245.22,10.147.245.23,10.147.245.24,10.147.245.25,10.147.245.26,10.147.245.27,10.147.245.28,10.147.245.29,10.147.245.30,10.147.245.31,10.147.245.32,10.147.245.33,10.147.245.34,10.147.245.35,10.147.245.36,10.147.245.37,10.147.245.38,10.147.245.39
all_proxy=socks://10.1.113.15:1010/
ftp_proxy=http://10.1.113.15:1010/
HTTP_PROXY=http://10.1.113.15:1010/
FTP_PROXY=http://10.1.113.15:1010/
ALL_PROXY=socks://10.1.113.15:1010/
NO_PROXY=localhost,127.0.0.0/8,::1,10.128.0.0/16,10.147.245.11,10.147.245.12,10.147.245.13,10.147.245.14,10.147.245.15,10.147.245.16,10.147.245.17,10.147.245.18,10.147.245.19,10.147.245.20,10.147.245.21,10.147.245.22,10.147.245.23,10.147.245.24,10.147.245.25,10.147.245.26,10.147.245.27,10.147.245.28,10.147.245.29,10.147.245.30,10.147.245.31,10.147.245.32,10.147.245.33,10.147.245.34,10.147.245.35,10.147.245.36,10.147.245.37,10.147.245.38,10.147.245.39
HTTPS_PROXY=http://10.1.113.15:1010/
```
```
# sudo chmod 755 /etc/profile.d/http_proxy.sh
# nano /etc/profile.d/http_proxy.sh


https_proxy=http://10.1.113.15:1010/
http_proxy=http://10.1.113.15:1010/
no_proxy=localhost,127.0.0.0/8,::1,10.128.0.0/16,10.147.245.11,10.147.245.12,10.147.245.13,10.147.245.14,10.147.245.15,10.147.245.16,10.147.245.17,10.147.245.18,10.147.245.19,10.147.245.20,10.147.245.21,10.147.245.22,10.147.245.23,10.147.245.24,10.147.245.25,10.147.245.26,10.147.245.27,10.147.245.28,10.147.245.29,10.147.245.30,10.147.245.31,10.147.245.32,10.147.245.33,10.147.245.34,10.147.245.35,10.147.245.36,10.147.245.37,10.147.245.38,10.147.245.39
all_proxy=socks://10.1.113.15:1010/
ftp_proxy=http://10.1.113.15:1010/
HTTP_PROXY=http://10.1.113.15:1010/
FTP_PROXY=http://10.1.113.15:1010/
ALL_PROXY=socks://10.1.113.15:1010/
NO_PROXY=localhost,127.0.0.0/8,::1,10.128.0.0/16,10.147.245.11,10.147.245.12,10.147.245.13,10.147.245.14,10.147.245.15,10.147.245.16,10.147.245.17,10.147.245.18,10.147.245.19,10.147.245.20,10.147.245.21,10.147.245.22,10.147.245.23,10.147.245.24,10.147.245.25,10.147.245.26,10.147.245.27,10.147.245.28,10.147.245.29,10.147.245.30,10.147.245.31,10.147.245.32,10.147.245.33,10.147.245.34,10.147.245.35,10.147.245.36,10.147.245.37,10.147.245.38,10.147.245.39
HTTPS_PROXY=http://10.1.113.15:1010/
```
```
# add one string at the end of file
# nano /etc/yum.conf


[main]
cachedir=/var/cache/yum/$basearch/$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=5
bugtracker_url=http://bugs.centos.org/set_project.php?project_id=23&ref=http://bugs.centos.org/bug_report_page.php?category=yum
distroverpkg=centos-release


#  This is the default, if you make this bigger yum won't see if the metadata
# is newer on the remote and so you'll "gain" the bandwidth of not having to
# download the new metadata and "pay" for it by yum not having correct
# information.
#  It is esp. important, to have correct metadata, for distributions like
# Fedora which don't keep old packages around. If you don't like this checking
# interupting your command line usage, it's much better to have something
# manually check the metadata once an hour (yum-updatesd will do this).
# metadata_expire=90m

# PUT YOUR REPOS HERE OR IN separate files named file.repo
# in /etc/yum.repos.d
proxy=http://10.1.113.15:1010
```

- All servers must have time synchronization configured (using **install_chrony.yml**). If time synchronization is already set and working, do not perform this step. If you want to use another time synchronization program, install it manually or by editing **install_chrony.yml**.  
```
ansible-playbook install_chrony.yml
```

### !!! Prepare OS !!!
- To do this! (using prepare_os.yml). Disable SELinux, Install common packages, Disable SWAP, Load required modules, Modify sysctl entries, Update OS if it need, Reboot OS (using **prepare_os.yml**).  
To understand the example see `hosts_example` file. Ansible installed on first master.  
First execute this on the host with ansible. In this example it is first K8S master. This is just an OS update.
```
ansible-playbook prepare_os.yml -e target=ansible
```
Then execute on the all other hosts K8S.  
```
ansible-playbook prepare_os.yml -e target='kube:!ansible'
```
If you need prepare OS on other servers not included in the cluster (for example, rdbms and etc.). This is just an OS update.
```
ansible-playbook prepare_os_others.yml -e target=others
```

Сheck settings 
```
ansible kube -m shell -a 'lsmod | grep br_netfilter' -b
ansible kube -m shell -a 'cat /etc/modules-load.d/k8s.conf'
ansible kube -m shell -a 'cat /etc/sysctl.conf'
```

#### Install specific version packages
If you need install specific version docker or kubernetes, you neet edit these yml files  
```
nano ~/ansible/roles/kubernetes-bootstrap/tasks/install_k8s_packages.yml
nano ~/ansible/roles/kubernetes-bootstrap/tasks/setup_docker.yml
```
Example changes  
```
[containerd.io-1.2.13,docker-ce-19.03.11,docker-ce-cli-19.03.11]
[kubelet-1.21.3,kubeadm-1.21.3,kubectl-1.21.3]
```

#### Update variables in playbook file k8s-prep.yml (presented variant when firewalld is completely removed)

In file **setup_docker.yml** specific versions of packages are indicated (taken from the documentation - https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker).  
You need to check which version of the packages is currently indicated in the documentation and, if necessary, fix it.


```
nano k8s-prep.yml
---
- name: Setup Proxy
  hosts: k8s-nodes
  # remote_user: <user>
  become: yes
  become_method: sudo
  # gather_facts: no
  vars:
    k8s_cni: calico                                      # calico, flannel
    container_runtime: docker                            # docker, cri-o, containerd
    configure_firewalld: false                            # true / false
    remove_firewalld: true                               # Set to true to remove firewalld	
    # Docker registry
    setup_proxy: false                                   # Set to true to configure proxy
    proxy_server: "proxy.example.com:8080"               # Proxy server address and port
    docker_proxy_exclude: "localhost,127.0.0.1"          # Adresses to exclude from proxy
  roles:
    - kubernetes-bootstrap
```

If you are using non root remote user, then set username and enable sudo:
```
become: yes
become_method: sudo
```

To **enable proxy**, set the value of `setup_proxy` to `true` and provide proxy details in **vars**: `proxy_server` and `docker_proxy_exclude`.  
To **remove Firewalld**, set the value of `remove_firewalld` to `true` and `configure_firewalld` to `false`.  
To **install and configure Firewalld**, set the value of `remove_firewalld` to `false` and `configure_firewalld` to `true`.  

## Running Playbook with role kubernetes-bootstrap

This playbook installed all needed software on all servers without creating the cluster itself.  
```
ansible-playbook k8s-prep.yml
```

### Additional options and checks after installation  
- Check versions  
```
sudo docker --version
sudo kubelet --version
# until the host is added to the cluster, the kubectl will generate an error
sudo kubectl version
sudo kubeadm version
ansible kube -m shell -a "docker --version && sudo kubelet --version && sudo kubeadm version" -b
```
- You can add any user to the `docker` group so that this user can run `docker` even without root\sudo permissions. After add you need relogin.  
```
sudo usermod -aG docker $USER
ansible kube -m shell -a "usermod -aG docker USERNAME" -b
```
- You can prevent update specific packages (only example for docker) during system update  
```
# CentOS
sudo yum update --exclude=docker
# Debiam\Ubunta
sudo apt-mark hold docker && sudo apt-get upgrade
sudo apt-mark unhold docker
```

---
### Kubernetes Cluster
Init manualy
#### Init Cluster on Master 
Examples of three different ways to initialize a cluster.  
```
ansible-playbook -i inventory/stand.yml k8s_init_cluster.yml --extra-vars "mc='kubeadm init'"
ansible-playbook -i inventory/stand.yml k8s_init_cluster.yml --extra-vars "mc='kubeadm init --pod-network-cidr=10.244.0.0/16'"
ansible-playbook -i inventory/stand.yml k8s_init_cluster.yml --extra-vars "mc='kubeadm init --control-plane-endpoint pp-vip-k8s.mydomen.com:8443 --upload-certs --pod-network-cidr 10.244.0.0/16'"
```

In folder `/root` will be created two files:
- `cluster_initialized.txt` - Cluster creation log and command for join workers.
- `pod_network_setup.txt` - Pod network installation log. 

To check the cluster you can execute (this is as example):
```
# kubectl get nodes -o wide
NAME              STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
rtz-ppd-mk8s-01   Ready    master   39m   v1.19.2   10.147.245.25   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   docker://19.3.11
# kubectl -n kube-system get pod
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

#### Join workers

Join all workers servers to cluster. Copy command for join workers from `/root/cluster_initialized.txt` to `join_workers.yml`.

```
ansible-playbook join_workers.yml
```

You can check on the master server
```
kubectl get nodes
```

### Clean up (if something went wrong while creating the cluster)

See https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#tear-down
```
# Undo controlplane init on master
sudo kubeadm reset
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```
