#!/usr/bin/bash

set -e

sudo mv /home/ubuntu/bigfix.sh /etc/rc.bigfix
sudo chmod o+x /etc/rc.bigfix

echo "/etc/rc.bigfix" >> /etc/rc.local
echo "sudo dhclient -r" >> /etc/rc.bigfix
echo "sudo dhclient -4" >> /etc/rc.bigfix
echo "sudo rm -f /etc/rc.bigfix" >> /etc/rc.bigfix
sudo reboot now
