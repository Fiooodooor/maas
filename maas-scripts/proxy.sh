#!/usr/bin/bash

set -e

function run_full_admin_proxy_script()
{
    creating_folders
    proxy
    debug_usr
    labrat_usr
    ssh_config
    #mv_files
}

function proxy()
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

function creating_folders()
{
    sudo touch /etc/apt/apt.conf.d/proxy.conf
}

function debug_usr()
{
    sudo adduser --disabled-password debug <<< ""
    sudo usermod -aG sudo debug
    sudo echo "debug:r00tme" | sudo chpasswd
}

function labrat_usr()
{
    sudo adduser --disabled-password labrat <<< ""
    sudo usermod -aG sudo labrat
    sudo echo "labrat:r00tme" | sudo chpasswd
}

function mv_files()
{
    sudo cp  /home/debug/.bashrc /home/ubuntu/
    sudo cp  /home/debug/.Xauthority /home/ubuntu/
    sudo cp  /home/debug/.bash_logout /home/ubuntu/
    sudo cp -R /home/debug/.cache /home/ubuntu/
    sudo cp  /home/debug/.profile /home/ubuntu/
}

function ssh_config()
{
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
}

run
