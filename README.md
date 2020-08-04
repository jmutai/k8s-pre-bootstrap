## Main info

This playbook helps you setting up a Kubernetes Cluster on VM or bare-metal servers.
The entire installation is performed under sudo user account.

## Supported OS

- CentOS 7

## Documentation

https://kubernetes.io/docs/setup/production-environment/

## Additional playbooks

- net_config_copy.yml - Copy /etc/host and /etc/resolv.conf to another servers.
- prepare_os.yml - Prepare OS.
- check_uniq.yml - Verify the MAC address and product_uuid are unique for every node (https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#verify-mac-address)
- send_public_key.yml - Deploy the public key to remote hosts (for ssh)
- create_cluster.yml - Creating a single control-plane cluster with kubeadm (https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

## Preliminary preparation of the master server

- Install git and ansible on the control computer
```
sudo yum install -y epel-release
sudo yum install -y ansible
sudo yum install -y git
sudo yum install -y platform-python
```

- Clone the Git Project to folder /root/ansible:
```
cd ~
mkdir ansible
cd ansible
git clone https://github.com/MinistrBob/k8s-pre-bootstrap.git .
cp hosts_example hosts
```

- Setting up ansible
```
ansible --version (you can see where config)
sudo nano /etc/ansible/ansible.cfg
```

such settings
```
inventory = /home/<user>/ansible/hosts
host_key_checking = False
```

- Edit file hosts (list of servers)
```nano hosts```

# Deploy the public key to remote hosts (setup passwordless authentication)

- Generate keys
```
ssh-keygen -t rsa
```

- Edit send_public_key.yml, insert in ```line:``` line with public key from /home/<user>/.ssh/id_rsa.pub. You can see key ```cat /home/<user>/.ssh/id_rsa.pub```

- Edit send_public_key.yml, insert user name (user under whom the installation is performed) instead of <user>

- Deploy key with ansible
```
ansible-playbook send_public_key.yml -b --ask-pass
```
## Preliminary preparation infrastructure

- It is desirable that all servers distinguish each other by name. To do this, either you need to have a configured DNS or prepare files /etc/host and /etc/resolv.conf on the master and copy them to other servers using net_config_copy.yml.
```ansible-playbook net_config_copy.yml```
- All servers must have time synchronization configured (using install_chrony.yml).
```ansible-playbook install_chrony.yml```

## !!! Prepare OS !!!
- To do this! (using prepare_os.yml). Disable SELinux, Install common packages, Disable SWAP, Load required modules, Modify sysctl entries, Update OS if it need, Reboot OS.
```ansible-playbook prepare_os.yml```

## Update variables in playbook file k8s-prep.yml (presented variant when firewalld is completely removed)

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

To enable proxy, set the value of `setup_proxy` to `true` and provide proxy details.

## Verify the MAC address and product_uuid are unique for every node

Playbook show MAC addresses and UUID. If VMs were cloned, then they may have not uniqu MAC and UUID. **You must visually verify that everything is unique**.  
```
ansible-playbook check_uniq.yml
```

## Running Playbook with role kubernetes-bootstrap

This playbook installed all needed software on all servers without creating the cluster itself.  

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

## Running Playbook

Once all values are updated, you can then run the playbook against your nodes.

