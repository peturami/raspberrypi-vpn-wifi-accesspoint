#!/bin/bash

#set -x

##---------------------------------------------------------------------------------------------------------------------
# KEY INPUT
##---------------------------------------------------------------------------------------------------------------------

SERVER=
SERVERRENAMED="VPNServerTCP.ovpn"

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		--server)              SERVER="$2";           shift;;
		*)
		    echo 1>&2 $0: Unknown option $key=$1.
		;;
	esac
	shift
done

## --------------------------------------------------------------------------------------------------------------------
# CONFIGURATION
## --------------------------------------------------------------------------------------------------------------------

# check for mandatory parameters and print help in case any of them is empty.
if [[ -z "$SERVER" ]]; then
cat <<EOF
    Missing mandatory parameter:
    --server  mandatory example: uk2228 link: https://nordvpn.com/servers/
EOF
	exit 1
fi

# upgrade & update system
sudo apt-get upgrade
sudo apt-get update

# install openvpn
sudo apt-get install openvpn -y

# cd to openvpn folder
cd /etc/openvpn

# ask user for his nordvpn credentials: email+pass and save it to authentification file
read -p 'NORDVPN username (email): ' USR
read -sp 'Password: ' PASSW
echo
echo -e "${USR}\n${PASSW}" | sudo tee .login > /dev/null
sudo chmod +x .login

# get the ovpn file from nordvpn download page
sudo wget https://downloads.nordcdn.com/configs/files/ovpn_tcp/servers/${SERVER}.nordvpn.com.tcp.ovpn

# remove renamed VPN file if exists (for repeated runs)
rm -f -- ${SERVERRENAMED}
# rename ovpn file to simplier name
sudo mv ${SERVER}.nordvpn.com.tcp.ovpn ${SERVERRENAMED}
sudo chmod +x ${SERVERRENAMED}

# modify ovpn file - add .login
search="auth-user-pass"
replace="auth-user-pass \/etc\/openvpn\/.login"
sudo sed -i "s/$search/$replace/gi" ${SERVERRENAMED}

# enable ipv4 forwarding
search="#net.ipv4.ip_forward"
replace="net.ipv4.ip_forward"
sudo sed -i "s/$search/$replace/gi" /etc/sysctl.conf
# enable the service
sudo sysctl -p

# reroute the eth0 traffic through our VPN  tunnel using iptables.
# flush current iptables
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
#forward all eth0 traffic over the VPN tunnel connection
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

# persist iptables setting
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
# start the routing rules
sudo systemctl enable netfilter-persistent

# start VPN automatically after booting your Raspberry
# create vpn_start.sh
echo -e "sudo killall openvpn\nsudo -b openvpn /etc/openvpn/${SERVERRENAMED}" | sudo tee /etc/openvpn/vpn_start.sh > /dev/null
sudo chmod +x /etc/openvpn/vpn_start.sh
# run vpn_start.sh automatically
search="exit 0"
replace="\n\/etc\/openvpn\/vpn_start.sh\n\n${search}"
sudo sed -i "s/$search/$replace/gi" /etc/rc.local

# install RaspAp
curl -sL https://install.raspap.com | bash

# setting wlan server help prevent DNS leak
echo -e "interface=wlan0\nserver=1.1.1.1" | sudo tee -a /etc/dnsmasq.conf > /dev/null

# reboot Rasbperry
sudo reboot
