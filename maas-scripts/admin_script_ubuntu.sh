#!/usr/bin/env bash

. credentials_ubuntu.sh

set -euf -o pipefail

function run_full_admin_script()
{
        #enable_uid_of_root_login_via_ssh
        create_debug_acc_with_passwd
        enable_accounts_login_via_ssh
        create_sys_cert_user_without_passwd
	#set_proxy
}

function set_proxy()
{
    sudo chmod a+w /etc/environment
    echo 'export http_proxy="http://proxy-dmz.intel.com:911"' >> /etc/environment
    echo 'export https_proxy="http://proxy-dmz.intel.com:912"' >> /etc/environment
    echo 'export ftp_proxy="http://proxy-dmz.intel.com:21"' >> /etc/environment
    echo 'export no_proxy="intel.com,.intel.com,10.0.0.0/8,192.168.0.0/16,localhost,.local,127.0.0.0/8,172.16.0.0/12,134.134.0.0/16"' >> /etc/environment
    echo 'export HTTP_PROXY="http://proxy-dmz.intel.com:911"' >> /etc/environment
    echo 'export HTTPS_PROXY="http://proxy-dmz.intel.com:912"' >> /etc/environment
    echo 'export FTP_PROXY="http://proxy-dmz.intel.com:21"' >> /etc/environment
    echo 'export NO_PROXY="intel.com,.intel.com,10.0.0.0/8,192.168.0.0/16,localhost,.local,127.0.0.0/8,172.16.0.0/12,134.134.0.0/16"' >> /etc/environment
    sud chmod a-w /etc/environment

    sudo touch /etc/apt/apt.conf.d/proxy.conf
    sudo echo 'Acquire::http::proxy="http://proxy-dmz.intel.com:911";' >> /etc/apt/apt.conf.d/proxy.conf
    sudo echo 'Acquire::https::proxy="http://proxy-dmz.intel.com:912";' >> /etc/apt/apt.conf.d/proxy.conf
}

function enable_uid_of_root_login_via_ssh()
{
        sudo sed -i 's/^no-port-forwarding.\+exit 142" //g' /root/.ssh/authorized_keys
        sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
        sudo sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
        sudo systemctl restart ssh
}

function create_debug_acc_with_passwd()
{
        sudo adduser --disabled-password debug <<< ""
        sudo usermod -aG sudo debug
        sudo echo "debug:$password_for_debug_account" | sudo chpasswd
        sudo rm -rf credentials_ubuntu.sh
        password_for_debug_account=""
}

function enable_accounts_login_via_ssh()
{
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo systemctl restart ssh
}

function create_sys_cert_user_without_passwd()
{
        useradd -m sys_cert
        sudo mkdir -m 0700 /home/sys_cert/.ssh
        sudo touch /home/sys_cert/.ssh/authorized_keys
        sudo chmod 0600 /home/sys_cert/.ssh/authorized_keys
        sudo chown ubuntu /home/sys_cert/.ssh/authorized_keys
        echo 'from="10.11.170.??,10.11.228.2??,10.11.216.1??,10.108.18.1??,10.108.131.2??,10.109.192.1??,10.108.48.1??,10.109.78.2??,10.109.6.??,10.184.198.49,10.18.59.??,10.11.204.2??,10.11.127.1??,10.4.49.2??,10.18.241.1??,10.63.75.19?,10.63.75.2??,10.4.153.19?,10.4.153.2??,10.63.70.1??,10.64.107.1??,10.108.202.??,10.108.65.19?,10.108.65.2??,10.108.75.??",no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4EL1Jn5XHHJSflcPyDOqzG2+CV2bPdgoDoSeQC9fltFD2s9WAlgLZl/ysKy+PwpSN3V1PzN+k56kKlUGX65EdPySs8AF5/aEwPD7QvIjoH5zojL3PBn+JdGBQuanGe+jM4ZUov+79pL2LZJNr4yT9qcwS+huNIyo+Ay6wd9cmgYfiZwOktHNZiKsE0OIPYTiviXTtqar58Vu6GeK3tm6esOOWls6iI5GbDYXrYWCNMsiScLClnWNKh0NhEHlubPK2Ezild/pMlOwMCIuKWcbW2b5C6AwdMAPsbvAjKziwPYUGeGlVkqPB/X+X3t9l1Rv5WunxLycv2St09K7twgasnd5XwGrb4iXmMmZIYUgbdXhN84+DgekBLf3/8wASPyBLL0ZCUFCuYxAzEFpQCPGlwYePSF6a90F2mNMDxqOVsAxsTyx6PCPrRn68lpRlAgR5enVlgNI/lIY8FqfT7+eW0Bm3ZuA1xxhGEgiJQQOmas+ICDKCrnlqwTLqEynW/kvcjcyCt//TDGuwOh2KY2+DjjV3gSyWN7niktSTYG0jN7hXf8/OnDM91D4+XgeT3HM/kpDfK03lBuGBeUZa0BPdHXueXr4GxlHg34VtfOM5z9Fsp9Tjv5FmoaHfRNdZLz71JqQitGhQMdPo/osYrbPkmCWnsQKBx7ll5M7uH2OPbQ==' \
          | sudo tee -a /home/sys_cert/.ssh/authorized_keys
        sudo chown -R sys_cert:sys_cert /home/sys_cert/

        echo 'HostKeyAlgorithms +ssh-rsa' | sudo tee -a /etc/ssh/sshd_config
        echo 'PubkeyAcceptedKeyTypes +ssh-rsa' | sudo tee -a /etc/ssh/sshd_config
        sudo systemctl restart ssh
}

run_full_admin_script
