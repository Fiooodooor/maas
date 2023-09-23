#!/usr/bin/env bash

set -ex

SCRIPT_DIRECTORY="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"

function initialize_variables()
{
export DEBIAN_FRONTEND=noninteractive
export LXD_HTTPS_PORT='30005'
export LXD_BRG_IFACE='ens802'
export LXD_BRG_SUBNET='10.10.100.0/24'
export LXD_BRG_IP_ADDR='10.10.100.1/24'
export LXD_BRG_IP_START='10.10.100.200'
export LXD_BRG_IP_END='10.10.100.254'
export MAAS_HTTPS_PORT=30006
export INTERFACE=($(ip -j route show default | jq -r '.[].dev'))
export IP_ADDRESS=($(ip -j route show default | jq -r '.[].prefsrc'))
[[ "${IP_ADDRESS[0]}" = "null" ]] && export IP_ADDRESS=$(ip -j addr show ${INTERFACE[0]} | jq -r '.[].addr_info[] | select(.family == "inet") | .local')

( 
cat <<EOF
config:
  core.https_address: '[::]:${LXD_HTTPS_PORT}'
  core.trust_password: password
networks:
- config:
    ipv4.address: ${LXD_BRG_IP_ADDR}
    ipv4.nat: true
    ipv6.address: none
  description: "Basic LXD bridge configuration"
  name: lxdbr0
  type: ""
  project: default
storage_pools:
- config:
    size: 6000GB
  description: ""
  name: default
  driver: zfs
profiles:
- config: {}
  description: ""
  devices:
    ${LXD_BRG_IFACE}:
      name: ${LXD_BRG_IFACE}
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
projects: []
cluster: null
EOF
) > /tmp/lxd.cfg

}

function install_dependencies()
{
    sudo apt-add-repository -y ppa:maas/3.3
    sudo apt-get update
    sudo apt-get -y install jq cpu-checker bridge-utils \
         libevent-dev openssh-server software-properties-common ca-certificates apt-transport-https gnupg \
         qemu-kvm qemu libvirt0 libvirt-clients libvirt-daemon-driver-lxc libvirt-daemon libvirt-daemon-system libvirt-dev
    sudo snap refresh
    sudo snap install --channel=latest/stable lxd
    sudo snap set lxd ui.enable=true
    sudo snap restart --reload lxd
    sudo lxc config set core.https_address :30005
    sudo snap install maas-test-db
    sudo apt-get -y install maas
}

function lxd_basic_initialisation()
{
    sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sudo sysctl -p
    sudo iptables -t nat -A POSTROUTING -o $INTERFACE -j SNAT --to $IP_ADDRESS
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    sudo apt-get install iptables-persistent -y

    sudo adduser "ubuntu" lxd || true
    sudo adduser root lxd || true

    cat /tmp/lxd.cfg | lxd init --preseed
    lxd waitready
}

function maas_basic_initialisation()
{
    # Initialise MAAS
    maas init region+rack --database-uri maas-test-db:/// --maas-url http://${IP_ADDRESS}:${MAAS_HTTPS_PORT}/MAAS
    echo "Waiting for init to finish... "
    for it in $(seq 15 -1 0); do sleep 1; printf " $it"; done
    # Create MAAS admin and grab API key
    maas createadmin --username admin --password admin --email admin
}

function maas_client_login()
{
    export APIKEY=$(maas apikey --username admin)

    # MAAS admin login
    maas login admin "http://localhost:${MAAS_HTTPS_PORT}/MAAS/" $APIKEY
}

function maas_basic_configuration()
{
    # Configure MAAS networking (set gateways, vlans, DHCP on etc)
    export FABRIC_ID=$(maas admin subnet read "${LXD_BRG_SUBNET}" | jq -r ".vlan.fabric_id")
    export VLAN_TAG=$(maas admin subnet read "${LXD_BRG_SUBNET}" | jq -r ".vlan.vid")
    export PRIMARY_RACK=$(maas admin rack-controllers read | jq -r ".[] | .system_id")
    maas admin subnet update ${LXD_BRG_SUBNET} gateway_ip=${LXD_BRG_IP_ADDR}
    maas admin ipranges create type=dynamic start_ip=${LXD_BRG_IP_START} end_ip=${LXD_BRG_IP_END}
    maas admin vlan update $FABRIC_ID $VLAN_TAG dhcp_on=True primary_rack=$PRIMARY_RACK

    # Set Intel-IT Ubuntu mirrors as primary repository
    UBUNTU_MAIN_ARCHIVE=$(maas admin package-repositories read | jq '.[] | select(.name=="main_archive") | .id')
    maas admin package-repository update "${UBUNTU_MAIN_ARCHIVE}" disable_sources=false enabled=true url=http://linux-ftp.fi.intel.com/pub/mirrors/ubuntu

    # Enable and configure upstream DNS server
    maas admin maas set-config name=upstream_dns value="10.248.2.1 10.125.145.36 1.1.1.1"
    maas admin maas set-config name=dnssec_validation value="no"

    # Enable HTTP proxy for use in MAAS
    maas admin maas set-config name=enable_http_proxy value=true
    maas admin maas set-config name=prefer_v4_proxy value=true
    maas admin maas set-config name=http_proxy value=http://proxy-mu.intel.com:911/
}

function maas_ssh_keys_configuration()
{
    echo "MAAS keys generate and add to admin:"
    ssh-keygen -t ed25519 -b 4096 -f /root/.ssh/ssh_maas_root_ed25519 -N '' -C 'ssh_root@maas_regiond'
    ssh-keygen -t ed25519 -b 4096 -f /home/ubuntu/.ssh/ssh_maas_ubuntu_ed25519 -N '' -C 'ssh_ubuntu@maas_regiond'
    chown ubuntu:ubuntu /home/ubuntu/.ssh/ssh_maas_ubuntu_ed25519 /home/ubuntu/.ssh/ssh_maas_ubuntu_ed25519.pub
    chmod 600 /root/.ssh/ssh_maas_root_ed25519 /home/ubuntu/.ssh/ssh_maas_ubuntu_ed25519
    chmod 644 /root/.ssh/ssh_maas_root_ed25519.pub /home/ubuntu/.ssh/ssh_maas_ubuntu_ed25519.pub
    maas admin sshkeys create key="$(cat /root/.ssh/ssh_maas_regiond_ed25519.pub)"
    maas admin sshkeys create key="$(cat /home/ubuntu/.ssh/ssh_maas_ubuntu_ed25519.pub)"
    maas admin sshkeys create key="$(cat ${SCRIPT_DIRECTORY}/team_ssh.pub)"

    maas admin vm-hosts create  password=password  type=lxd power_address=https://${IP_ADDRESS}:${LXD_HTTPS_PORT} project=maas
}

initialize_variables
install_dependencies
lxd_basic_initialisation
maas_basic_initialisation
maas_client_login
maas_basic_configuration
maas_ssh_keys_configuration
