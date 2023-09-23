#!/usr/bin/bash

set -euo pipefail

function run_install_drivers_on_bare_metal()
{
	install_drivers_on_bare_metal
}

function install_drivers_on_bare_metal()
{
	cd /drivers
	tar -xf ice-1.6.7.tar.gz
	cd ice-1.6.7/src
	sudo apt-get update && sudo apt-get install -y gcc make linux-headers-$(uname -r)
	sudo make
	sudo make install
}

run_install_drivers_on_bare_metal
