```bash
sudo su
apt-get update
apt-get purge -y *lxd* *lxc*
apt-get autoremove -y
apt-add-repository -y ppa:maas/3.3
apt update
apt upgrade -y
```

Reboot the machine and run:

```bash
apt update
apt-get -y install jq cpu-checker bridge-utils qemu-kvm qemu \
     libvirt0 libvirt-clients libvirt-daemon-driver-lxc libvirt-daemon libvirt-daemon-system libvirt-dev
snap refresh
snap install --channel=latest/stable lxd
snap refresh --channel=latest/stable lxd
snap set lxd ui.enable=true
snap restart --reload lxd
lxc config set core.https_address :30005
snap install maas-test-db
apt-get -y install maas
```

```bash
wget -qO- https://raw.githubusercontent.com/canonical/maas-multipass/main/maas.yml \
 | multipass launch --name maas -c4 -m8GB -d32GB --cloud-init -
```

```yaml
write_files:
- content: |
    config:
      core.https_address: '[::]:30005'
      core.trust_password: password
    networks:
    - config:
        ipv4.address: 10.10.10.1/24
        ipv6.address: none
      description: ""
      name: lxdbr0
      type: ""
      project: default
    storage_pools:
    - config:
        size: 24GB
      description: ""
      name: default
      driver: zfs
    profiles:
    - config: {}
      description: ""
      devices:
        eth0:
          name: eth0
          network: lxdbr0
          type: nic
        root:
          path: /
          pool: default
          type: disk
      name: default
    projects: []
    cluster: null
  path: /tmp/lxd.cfg

packages:
  jq
snap:
  commands:
    - snap install maas
#    - snap install --channel=3.0/stable maas
    - snap install --channel=latest/stable lxd
    - snap refresh --channel=latest/stable lxd
    - snap install maas-test-db
runcmd:
# Fetch IPv4 address from the device, setup forwarding and NAT
- export IP_ADDRESS=$(ip -j route show default | jq -r '.[].prefsrc')
- export INTERFACE=$(ip -j route show default | jq -r '.[].dev')
- sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
- sysctl -p
- iptables -t nat -A POSTROUTING -o $INTERFACE -j SNAT --to $IP_ADDRESS
# Persist NAT configuration
- echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
- echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
- apt-get install iptables-persistent -y
# LXD init
- cat /tmp/lxd.cfg | lxd init --preseed
# Wait for LXD to be ready
- lxd waitready
# Initialise MAAS
- maas init region+rack --database-uri maas-test-db:/// --maas-url http://${IP_ADDRESS}:5240/MAAS
- sleep 15
# Create MAAS admin and grab API key
- maas createadmin --username admin --password admin --email admin
- export APIKEY=$(maas apikey --username admin)
# MAAS admin login
- maas login admin 'http://localhost:5240/MAAS/' $APIKEY
# Configure MAAS networking (set gateways, vlans, DHCP on etc)
- export SUBNET=10.10.10.0/24
- export FABRIC_ID=$(maas admin subnet read "$SUBNET" | jq -r ".vlan.fabric_id")
- export VLAN_TAG=$(maas admin subnet read "$SUBNET" | jq -r ".vlan.vid")
- export PRIMARY_RACK=$(maas admin rack-controllers read | jq -r ".[] | .system_id")
- maas admin subnet update $SUBNET gateway_ip=10.10.10.1
- maas admin ipranges create type=dynamic start_ip=10.10.10.200 end_ip=10.10.10.254
- maas admin vlan update $FABRIC_ID $VLAN_TAG dhcp_on=True primary_rack=$PRIMARY_RACK
- maas admin maas set-config name=upstream_dns value=8.8.8.8
# Add LXD as a VM host for MAAS
- maas admin vm-hosts create  password=password  type=lxd power_address=https://${IP_ADDRESS}:8443 project=maas
# Automatically create and add ssh keys to MAAS
- ssh-keygen -q -t rsa -N "" -f "/home/ubuntu/.ssh/id_rsa"
- chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa /home/ubuntu/.ssh/id_rsa.pub
- chmod 600 /home/ubuntu/.ssh/id_rsa
- chmod 644 /home/ubuntu/.ssh/id_rsa.pub
- maas admin sshkeys create key="$(cat /home/ubuntu/.ssh/id_rsa.pub)"
# Wait for images to be synced to MAAS
#- echo "Waiting for images to be synced to MAAS ..."
#- export status="downloading"
#- while [ "$status" != "synced" ]; do export status=$(maas admin rack-controller list-boot-images $PRIMARY_RACK | jq -r .status); sleep 1; done
```

```bash
sudo apt-add-repository ppa:maas/3.3
sudo apt update
sudo apt-get -y install maas
sudo systemctl disable --now systemd-timesyncd
```

```bash
KVM install:
sudo apt-add-repository ppa:maas/3.3
sudo apt update
sudo apt upgrade -y
sudo apt-get -y install bridge-utils qemu-kvm libvirt-bin

sudo apt -y install bridge-utils cpu-checker libvirt-clients libvirt-daemon qemu qemu-kvm libvirt-daemon-system
```

### Why use LXD on Ubuntu 22.04 LTS?

https://www.intel.com/content/dam/www/public/us/en/documents/guides/rmm-api-spec-v2-3.pdf

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
