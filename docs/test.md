Build result==>Artifactory

Build:
- Docker Buildx container (all architectures available)
- SIMICS container

Infrastructure:
Reservation and OS provisioning:
- VirtualMachine:
	- input spec: OS spec, Count, CPU core count, RAM amount, drive size
	- returns: SSH IP addresses, username, password
- BareMetal:
	- input spec: OS spec, Count. TAGs with requirements, optional CPU core count, RAM, drive
	- returns: SSH IP addresses, username, password
- Kubernetes/Docker/SIMICS
	- input: Nan
	- output: Kubeconfig with valid context

## Possible stack considerations

OS configuration:
- Custom ansible-playbook script based on inventory file rendered.
Commissioning

Jenkins Server (image):
	https://hub.docker.com/r/jenkins/jenkins
Jenkins Agent (image):
	https://hub.docker.com/r/jenkins/agent
Jenkins Agent SSH (image):
	https://hub.docker.com/r/jenkins/ssh-agent


Documentation:
	https://cluster-api.sigs.k8s.io/introduction
Implementation:
	https://github.com/spectrocloud/cluster-api-provider-maas


Ansible Automation Controller (Ansible Tower):
Ansible-AWX:
	https://github.com/ansible/awx/
Ansible-AWX-operator (kubernetes deployments):
	https://github.com/ansible/awx-operator
Ansible-AWX-resource-operator:
	https://github.com/ansible/awx-resource-operator
Ansible-Executors:
	https://github.com/ansible/awx-ee
	https://github.com/ansible/creator-ee
Ansible-Runner:
	https://github.com/ansible/ansible-runner




### Why use LXD on Ubuntu 22.04 LTS?

LXD is a container experience providing a ReST API to manage LXC containers. One can do the following things with LXD:

- Unprivileged containers (secure by design)
- Scalable
- Live migration
- Run containers
- Update containers
- Clustering support
- Ease of management
- Install different Linux distro inside containers
- Mimic AWS instance type on your local dev box
- Hardware passthrough support for GPU, USB, NIC, disks and more
- Advanced resource control for CPU, memory, disk/network I/O, kernel modules and more)
- Manage container resources, like storage volumes, map directories, memory/disk I/O restrictions, networking and more


## MAAS primary node installation:

```bash
sudo apt-get install lxc
echo 'USE_LXC_BRIDGE="true"' >> /etc/default/lxc-net
sudo systemctl start lxc-net
```

```bash
cat /etc/lxc/default.conf
# lxc.network.type = veth
# lxc.network.link = lxcbr0
# lxc.network.flags = up
# lxc.network.hwaddr = 00:16:3e:xx:xx:xx
```

### MAAS dockerized version - part of entrypoint.sh startup (example):

```bash
maas init region+rack --maas-url ${MAAS_URL} --database-uri ${PGCON} --force;
maas createadmin --username ${MAAS_PROFILE} --password ${MAAS_PASS} --email ${MAAS_EMAIL} --ssh-import ${MAAS_SSH_IMPORT_ID};
maas login ${MAAS_PROFILE} http://localhost:5240/MAAS \$(maas apikey --username ${MAAS_PROFILE});
bash
```

```bash
ssh-keygen -t ed25519 -b 4096 -f /home/ubuntu/.ssh/ssh_maas_regiond_ed25519 -N ''
```


## PostgreSQL primary node installation:

```bash
sudo apt install -y postgreql
sudo -u postgres psql -c "CREATE USER \"$MAAS_DB_OWNER\" WITH ENCRYPTED PASSWORD \'$MAAS_PASSWD'"
sudo -u postgres createdb -O "$MAAS_DB_OWNER" "$MAAS_DB_NAME"
```


## LXD and LXC installation:

### All questions and answers:

- Would you like to use LXD clustering? (yes/no) [default=no]: no
- Do you want to configure a new storage pool? (yes/no) [default=yes]: yes
- Name of the new storage pool [default=default]:  
- Name of the storage back-end to use (btrfs, dir, lvm, zfs, ceph) [default=zfs]: dir
- Would you like to connect to a MAAS server? (yes/no) [default=no]: no
- Would you like to create a new local network bridge? (yes/no) [default=yes]: no
- Would you like to configure LXD to use an existing bridge or host interface? (yes/no) [default=no]: yes
- Name of the existing bridge or host interface: br0
- Would you like LXD to be available over the network? (yes/no) [default=no]: yes
- Address to bind LXD to (not including port) [default=all]:
- Port to bind LXD to [default=8443]:
- Trust password for new clients:
- Would you like stale cached images to be updated automatically? (yes/no) [default=yes]
- Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]:


https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#behavioral-parameters


APT Packages:
python3-certifi python3-distlib python3-filelock python3-pip-whl python3-platformdirs python3-setuptools-whl python3-virtualenv python3-virtualenv-clone python3-wheel-whl
   
APT Packages:
setuptools virtualenv distlib certifi-2023.7.22

