#!/usr/bin/env bash

set -e

########
# VARS #
########

# colors

sudo apt install unzip

declare -A _COLOR

_COLOR[RED]='\033[0;31m'
_COLOR[YELLOW]='\033[0;33m'
_COLOR[GREEN]='\033[0;32m'
_COLOR[BLUE]='\033[1;34m'
_COLOR[WHITE_BOLD]='\033[1m'
_COLOR[RESET]='\033[0m'

# default var

_DEF_LAB_OWNER="kwywiol"
_DEF_REBOOT_CONTACT="cpietrux"
_DEF_SUPPORT_CONTACT="cpietrux"

# routes

declare -A _CERT_PWD

_CERT_PWD[Ubuntu]='/usr/local/share/ca-certificates/'
_CERT_PWD[Fedora]='/etc/pki/ca-trust/source/anchors/'

_CERT_LINKS=('http://certs.intel.com/crt/IntelSHA2RootChain-Base64.zip' 'http://certificates.intel.com/repository/certificates/Intel%20Root%20Certificate%20Chain%20Base64.zip')

_BIGFIX_LINK='https://isscorp.intel.com/IntelSM_BigFix/21074/All_BigFix_Client_Installers/Non_Windows/bigfix_non_windows-BESClient_Labs_Prod-TLS.sh'

_ACCOUNT_LINK='http://isscorp.intel.com/IntelSM_BigFix/33570/package/scan/labscanaccount.sh'

# PM

if [[ -x "$(command -v dnf)" ]]; then
	PM='dnf'
elif [[ -x "$(command -v apt)" ]]; then
	PM='apt'
else
	PM='<your-package-manager>'
fi

# functions

hr() {
	for _ in $(seq 1 $(tput cols)); do
		echo -n "="
	done
	echo
}

wget_unzip() {
	local temp='temp.zip'
	wget $1 -O $temp && unzip $temp -d ${_CERT_PWD[$DISTRO]}
	rm $temp
}

check_logs() {
	if [[ -n "$(grep 'Report posted' /var/opt/BESClient/__BESData/__Global/Logs/`date +%Y%m%d`.log)" ]]; then
			echo -e "${_COLOR[GREEN]}✓${_COLOR[RESET]}"
	else
			echo -e "${_COLOR[RED]}✗${_COLOR[RESET]}"
	fi
}

check_masthead() {
	local output="$(ls -l /etc/opt/BESClient/actionsite.afxm)"
	if [[ "${output::10}" ==  "-rw-------" ]]; then
			echo -e "${_COLOR[GREEN]}✓${_COLOR[RESET]}"
	else
			echo -e "${_COLOR[RED]}✗${_COLOR[RESET]}"
	fi
}


check_ps() {
	if [[ -n "$(ps --no-headers -C BESClient)" ]]; then
			echo -e "${_COLOR[GREEN]}✓${_COLOR[RESET]}"
	else
			echo -e "${_COLOR[RED]}✗${_COLOR[RESET]}"
	fi
}

check_command() {
	if ! [[ -x "$(command -v $1)" ]]; then
		echo -e "${_COLOR[RED]}Error:${_COLOR[RESET]} $1 is not installed"
		echo
		echo "Try this:"
		echo -e "${_COLOR[YELLOW]}sudo $PM install $1${_COLOR[RESET]}"
		needToExit=1
	fi
}


###############
# HELP SCRIPT #
###############

if [[ $* == *--help* || $* == *-h* ]]; then
	echo -e "Usage: ${_COLOR[YELLOW]}./BigFix_Installer.sh [FLAGS]${_COLOR[RESET]}"
	echo -e "Automates installation of ${_COLOR[BLUE]}BigFix Client${_COLOR[RESET]} on Linux"
	echo ""
	echo "Works on:"
	echo -e "  ${_COLOR[WHITE_BOLD]}Debian-based distros${_COLOR[RESET]} (Ubuntu, Kali etc.)"
	echo -e "  ${_COLOR[WHITE_BOLD]}Fedora${_COLOR[RESET]}"
	echo -e "  ${_COLOR[WHITE_BOLD]}CentOS${_COLOR[RESET]}"
	echo ""
	echo "Flags:"
	echo -e "  ${COLOR[WHITLE_BOLD]}--validate${_COLOR[RESET]} \t Validates installation of ${_COLOR[BLUE]}BigFix Client${_COLOR[RESET]}" 
	echo -e "  ${COLOR[WHITLE_BOLD]}-h, --help${_COLOR[RESET]} \t Displays this help"
	echo ""
	echo -e "In case of any problems and/or feedback, please contact ${_COLOR[WHITE_BOLD]}DominikX, Piotrowski${_COLOR[RESET]}"
	exit 0
fi

############
# CHECKING #
############

# check if run with sudo

if [[ ! $EUID == 0 ]]; then
	echo -e "${_COLOR[RED]}Error:${_COLOR[RESET]} No privilages"
	echo -e "Try this: ${_COLOR[YELLOW]}sudo !!${_COLOR[RESET]}"
	exit 1
fi

# check internet connection

if ! nc -zw1 intel.com 443; then
	echo ""
	echo -e "${_COLOR[RED]}Error:${_COLOR[RESET]} Cannot connect to intel.com"
	echo "Check your internet connection"
	exit 1
fi

needToExit=0

# check if unizp exsist

check_command 'unzip'

check_command 'ufw'

if [[ $needToExit == 1 ]]; then
	exit 1
fi

#################
# VALIDATE FLAG #
#################

if [[ $* == *--validate* ]]; then
	echo ""
	hr
	echo -e "  ${_COLOR[BLUE]}BIGFIX VALIDATION${_COLOR[RESET]}"
	hr
	echo ""

	echo -ne "${_COLOR[WHITE_BOLD]}Are logs preset?: ${_COLOR[RESET]}"
	check_logs

	echo -ne "${_COLOR[WHITE_BOLD]}Is the masthead file installed correctly?: ${_COLOR[RESET]}"
	check_masthead

	echo -ne "${_COLOR[WHITE_BOLD]}Is the agent service running?: ${_COLOR[RESET]}"
	check_ps

	exit 0
fi

###############
# MAIN SCRIPT #
###############

echo ""
hr
echo -e "  ${_COLOR[BLUE]}BIGFIX INSTALLER${_COLOR[RESET]}"
hr
echo ""
# check if /usr/bigfix exist

if [[ -e /usr/bigfix ]]; then
	echo -e "${_COLOR[YELLOW]}Warning:${_COLOR[RESET]} /usr/bigfix exist"
	echo "This could mean that BigFix is already installed"

	jumpout=0

	until [[ $jumpout == 1 ]]; do
		echo ""
		echo -ne "${_COLOR[WHITE_BOLD]}Procced anyway?${_COLOR[RESET]} [Y/n]: "
		read procced

		if [[ $procced == "n" || $procced == "N" ]]; then
			exit
		elif [[ $procced == "y" || $procced == "Y" ]]; then
			jumpout=1
		fi
	done
fi

# ask for distro

DISTRO=""

if [[ -x "$(command -v apt)" ]]; then
	DISTRO=Ubuntu
	echo "Your distro is Ubuntu"

elif [[ -x "$(command -v dnf)" ]]; then
	DISTRO=Fedora
	echo "Your distro is Fedora"
else
	while true; do
		echo "[1] Fedora, CentOS, Red Hat"
		echo "[2] Ubuntu, Debian"
		echo "[0] Exit"
		echo ""
		echo -en "${_COLOR[WHITE_BOLD]}Choose distro:${_COLOR[RESET]} "
		read pick

		if [[ $pick == "0" ]]; then
			exit 0
		elif [[ $pick == "1" ]]; then
			DISTRO=Fedora
			break;
		elif [[ $pick == "2" ]]; then
			DISTRO=Ubuntu
			break;
		fi
	done
fi

#ask for contact

echo ""
hr
echo -e "  ${_COLOR[WHITE_BOLD]}INSTALLING CERTIFICATES${_COLOR[RESET]}"
hr
echo ""

if [[ ! -e ${_CERT_PWD[$DISTRO]} ]]; then
	mkdir -p ${_CERT_PWD[$DISTRO]}
fi

for link in "${_CERT_LINKS[@]}"; do
	wget_unzip $link
done

if [[ $DISTRO == "Ubuntu" ]]; then
	update-ca-certificates
	c_rehash
else
	update-ca-trust force-enable
	update-ca-trust extract
fi

# bigfix contact

echo "LabOwner:piotrnow" >/usr/bigfix
echo "PrimaryRebootContact:piotrnow" >>/usr/bigfix
echo "PrimarySupportContact:piotrnow" >>/usr/bigfix

# install bigfix

echo ""
hr
echo -e "  ${_COLOR[WHITE_BOLD]}INSTALLING BIGFIX${_COLOR[RESET]}"
hr
echo ""

touch /etc/BFLinuxPatchEnabled
wget -4 -e use_proxy=no $_BIGFIX_LINK -O temp.sh && chmod +x temp.sh
bash temp.sh <"/usr/bigfix"
rm temp.sh

# create scan account

echo ""
hr
echo -e "  ${_COLOR[WHITE_BOLD]}CREATING SCAN ACCOUNT${_COLOR[RESET]}"
hr
echo ""
wget -4 -e use_proxy=no -N $_ACCOUNT_LINK -O temp.sh && bash temp.sh
echo ""
echo -e "  ${_COLOR[WHITE_BOLD]}Usuwanie temp.sh${_COLOR[RESET]}"
echo ""
rm temp.sh

# done

echo ""
echo -e "${_COLOR[BLUE]}*${_COLOR[RESET]}\(ˆ˚ˆ)/${_COLOR[BLUE]}*${_COLOR[RESET]}"
echo -e "${_COLOR[GREEN]}Success:${_COLOR[RESET]} BigFix installed"
echo -e "${_COLOR[YELLOW]}Note:${_COLOR[RESET]} Restart is required"
echo -e "${_COLOR[BLUE]}*${_COLOR[RESET]}\(ˆ˚ˆ)/${_COLOR[BLUE]}*${_COLOR[RESET]}"
echo ""
echo -e "${_COLOR[WHITE_BOLD]}CREATING SCAN ACCOUNT${_COLOR[RESET]}"
hr
echo ""
wget -4 -e use_proxy=no -N $_ACCOUNT_LINK -O temp.sh && bash temp.sh
echo ""
echo -e "  ${_COLOR[WHITE_BOLD]}USUWANIE TEMP.SH ${_COLOR[RESET]}"
echo ""

rm temp.sh

echo ""
echo -e "  ${_COLOR[WHITE_BOLD]}WYKONANO USUNIECIE${_COLOR[RESET]}"
echo ""

if [[ $DISTRO = "Ubuntu" ]]; then
		rm BESAgent.deb
else
		rm BESAgent.rpm
fi
echo ""
echo -e "  ${_COLOR[WHITE_BOLD]}USUNIETO BESAGENT${_COLOR[RESET]}"
echo ""

# Done

echo ""
echo -e "${_COLOR[BLUE]}*${_COLOR[RESET]}\(ˆ˚ˆ)/${_COLOR[BLUE]}*${_COLOR[RESET]}"
echo -e "${_COLOR[GREEN]}Success:${_COLOR[RESET]} BigFix installed"
echo -e "${_COLOR[YELLOW]}Note:${_COLOR[RESET]} Restart is required"
echo -e "${_COLOR[BLUE]}*${_COLOR[RESET]}\(ˆ˚ˆ)/${_COLOR[BLUE]}*${_COLOR[RESET]}"
echo ""

sudo dhclient -4
