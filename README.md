# Raspberry wifi VPN access point

This tutorial shows how to turn Raspberry PI into wifi VPN access point using NordVPN (openvpn) and [RaspAP](https://raspap.com/).

I could not find working solution to get it work, but these steps finally worked in my case.

## Prerequisites
- Raspberry PI and Raspbian OS installed
- OpenVPN based VPN client

## Installation

#### Using script:
To automate whole process I wrote simple script that makes all the dirty work. **Automation works only for nordvpn, for other vpn services follow manual steps.**

Script expects the only parameter (nordvpn server name), example:
```bash
./install --server uk1234
```
Full list of available servers you can find here [nordpvn servers](https://nordvpn.com/servers/).

#### Manual setting:

1) Update & upgrade Raspian OS
```bash
sudo apt-get upgrade
sudo apt-get update
```

2) Install openvpn client
```bash
sudo apt-get install openvpn -y
```

3) Create VPN authentification file and type in your username and password, each to new line. (then save the changes and exit the file - control+x type y and press enter)
```bash
cd /etc/openvpn
sudo nano .login
```
Make the file executable:
```bash
sudo chmod +x .login
```

4) Download ovpn configuration file from NordVPN.
```bash
sudo wget https://downloads.nordcdn.com/configs/files/ovpn_tcp/servers/uk1234.nordvpn.com.tcp.ovpn
```
Full list of available servers you can find on [nordpvn servers](https://nordvpn.com/servers/). It is also possible download tcp file manualy from your web browser and save it to destination path /etc/openvpn.

Rename it for easy use:
```bash
sudo mv uk1234.nordvpn.com.tcp.ovpn VPNServerTCP.ovpn
```

5) Setup the VPN access point

Open ovpn file and search for the line with text auth-user-pass. Add path to your auth file at this line.
```bash
sudo nano VPNServerTCP.ovpn
```
Type in: *auth-user-pass /etc/openvpn/.login*
> then save the changes - control-x, type y and press enter

After rebooting your Raspberry PI (sudo reboot) you should be able to test VPN connection.
```bash
sudo openvpn –config “/etc/openvpn/VPNServerTCP.ovpn”
```
This should return something like following and means you just made successful connection to NordVPN server:
> ...
> "Initialization Sequence Completed"

Now it's essential to enable route forwarding. To make it done we have to edit /etc/sysctl.conf.
```bash
sudo nano /etc/sysctl.conf
```
Uncomment line *(remove the leading #)* #net.ipv4.ip_forward =1
> then save the changes - control-x, type y and press enter

Enable the service:
```bash
sudo sysctl -p
```

Now it is time to reroute the eth0 traffic through our VPN tunnel using iptables.
Flush current iptables:
```bash
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
```

Forward all eth0 traffic over the VPN tunnel connection:
```bash
sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
```

Save iptables settings, otherwise this settings will be lost after reboot. Install iptables persistant, save the settings and start the routing rules.
```bash
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
sudo systemctl enable netfilter-persistent
```

Start VPN automatically after your Raspberry PI is up.
Create new file with following code:
```bash
sudo nano /etc/openvpn/vpn_start.sh
```
> sudo killall openvpn
>
> sudo -b openvpn /etc/openvpn/uk2228TCP.ovpn

Make it executable:
```bash
sudo chmod +x /etc/openvpn/vpn_start.sh
```

To run it automatically edit */etc/rc.local* and copy /etc/openvpn/vpn_start.sh to the end of the file right in front of the line with *exit 0*
> then save the changes - control-x, type y and press enter

After rebooting your Raspberry VPN tunnel should be already available, which you can check using *ifconfig* command.

6) Install RaspAP to turn your Raspberry PI into wifi access point.

There I just followed official documentation on [RaspAP](https://raspap.com/)
```bash
curl -sL https://install.raspap.com | bash
```

At this moment you have working wireless VPN access point.

	IP address: 10.3.141.1.
	Username: admin
	Password: secret
	DHCP range: 10.3.141.50 - 10.3.141.255
	SSID: raspi-webgui
	Password: ChangeMe

`Don't forget to change the passwords!`

Very last step. At this moment everything seemed fine and working, but there was DNS leak *(you can check it using* [dnsleaktest.com](https://www.dnsleaktest.com/)).

To fix this I've found several potential solutions, but
this one worked [Raspberrypi Stack Exchange](https://raspberrypi.stackexchange.com/questions/109182/preventing-dns-leaks-on-raspberry-pi-vpn-router).
```bash
sudo nano /etc/dnsmasq.conf
```
Add following to the end of the file:
> interface=wlan0       # Use interface wlan0
>
> server=1.1.1.1        # Dns Cloudfare Server
