## Main info

This playbook helps you setting up a Kubernetes Cluster on VM or bare-metal servers.
The entire installation is performed under root account (sudo su -). If you have a different account is used in all commands sudo (sudo some command).

## Supported OS

- CentOS 7

## Tasks in the role

This role contains tasks to:

- Install basic packages required
- Setup standard system requirements - Disable Swap, Modify sysctl, Disable SELinux
- Install and configure a container runtime of your Choice - cri-o, Docker, Containerd
- Install the Kubernetes packages - kubelet, kubeadm and kubectl
- Configure Firewalld on Kubernetes Master and Worker nodes

## Additional playbooks

- check_uniq.yml - Verify the MAC address and product_uuid are unique for every node (https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#verify-mac-address)
- send_public_key.yml - Deploy the public key to remote hosts
- create_cluster.yml - Creating a single control-plane cluster with kubeadm (https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

## Preliminary preparation

- Install git and ansible on the control computer
```
sudo yum install -y epel-release
sudo yum install -y ansible
sudo yum install -y git
sudo yum install -y platform-python
```

- Setting up ansible
```
sudo nano /etc/ansible/ansible.cfg
```

```
inventory = /root/ansible/hosts
host_key_checking = False
```

## Creating cluster

- Clone the Git Project:
```
$ git clone https://github.com/MinistrBob/k8s-pre-bootstrap.git
```

- Verify the MAC address and product_uuid are unique for every node. 
Playbook show MAC addresses and UUID. You must visually verify that everything is unique :)  
```
ansible-playbook check_uniq.yml
```
- Install ansible (better on the master)
```
sudo yum install -y epel-release
sudo yum install -y ansible
ansible --version (where config)
```

* Deploy the public key to remote hosts
    - Generate keys
    ```
    ssh-keygen -t rsa
    ```
    - Edit send_public_key.yml, insert in ```line:``` line with public key from /home/<user>/.ssh/id_rsa.pub
    - Deploy key with ansible
    ```
    ansible-playbook send_public_key.yml -b --ask-pass
    ```

- Update your inventory, e.g:
```
$ nano hosts
[master]
172.26.12.130

[workers]
172.26.12.131
172.26.12.132
172.26.12.133

```

- Update variables in playbook file (presented variant when firewalld is completely removed)
```
$ nano k8s-prep.yml
---
- name: Setup Proxy
  hosts: k8s-nodes
  remote_user: root
  become: yes
  become_method: sudo
  #gather_facts: no
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

To enable proxy, set the value of `setup_proxy` to `true` and provide proxy details.

## Running Playbook

Once all values are updated, you can then run the playbook against your nodes.

**NOTE**: For firewall configuration to open relevant ports for master and worker nodes, a pattern in hostname is required.

Check file:
```
$ nano roles/kubernetes-bootstrap/tasks/configure_firewalld.yml
....
- name: Configure firewalld on master nodes
  firewalld:
    port: "{{ item }}/tcp"
    permanent: yes
    state: enabled
  with_items: '{{ k8s_master_ports }}'
  when: "'master' in ansible_hostname"

- name: Configure firewalld on worker nodes
  firewalld:
    port: "{{ item }}/tcp"
    permanent: yes
    state: enabled
  with_items: '{{ k8s_worker_ports }}'
  when: "'node' in ansible_hostname"
```

If your master nodes doesn't contain `master` and nodes doesn't have `node` as part of hostname, update the file to reflect your naming pattern. My nodes are named like below:
```
k8smaster01
k8snode01
k8snode02
k8snode03
```

## Running Playbook

Playbook executed as root user - with ssh key:
```
$ ansible-playbook -i hosts k8s-prep.yml
```

Playbook executed as root user - with password:
```
$ ansible-playbook -i hosts k8s-prep.yml --ask-pass
```

Playbook executed as sudo user - with password:
```
$ ansible-playbook -i hosts k8s-prep.yml --ask-pass --ask-become-pass
```

Playbook executed as sudo user - with ssh key and sudo password:
```
$ ansible-playbook -i hosts k8s-prep.yml --ask-become-pass
```

Playbook executed as sudo user - with ssh key and passwordless sudo:
```
$ ansible-playbook -i hosts k8s-prep.yml --ask-become-pass
```

Execution should be successful without errors.
