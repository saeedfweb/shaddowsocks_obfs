#!/bin/bash  -
#===============================================================================
#
#          FILE: setup.sh
#
#         USAGE: ./setup.sh
#
#   DESCRIPTION: This script will install and configure shadowsocks on internal and external host
#
#       OPTIONS: ---
#  REQUIREMENTS: Debian or Ubuntu, Bash
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Morteza Bashsiz (), morteza.bashsiz@gmail.com
#  ORGANIZATION: 
#       CREATED: 10/05/2022 10:25:37 PM
#      REVISION:  ---
#===============================================================================

set -o nounset                                  # Treat unset variables as an error

_DISTRO=""
_PKGMGR=""

_HostIP=$(awk '/32 host/ { print f } {f=$2}' <<< "$(</proc/net/fib_trie)" | grep -v 127.0.0.1 | sort -n | uniq)
_internalIP=$(grep "^internalIP" config | awk -F = '{print $2}')
_internalPort=$(grep "^internalPort" config | awk -F = '{print $2}')
_externalIP=$(grep "^externalIP" config | awk -F = '{print $2}')
_externalPort=$(grep "^externalPort" config | awk -F = '{print $2}')

_isInternal=$(echo "$_HostIP" | grep "$_internalIP")
_isExternal=$(echo "$_HostIP" | grep "$_externalIP")

if [[ "$_isExternal" ]]
then
	_UNAME=$(grep "^NAME=" /etc/os-release)
	_pass=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c"${1:-16}";echo;)
	
	if [[ "$_UNAME" == *"Debian"*  ]]
	then
	  _DISTRO="DEBIAN"
	  _PKGMGR="apt-get"
	elif [[ "$_UNAME" == *"Ubuntu"*  ]]
	then
	  _DISTRO="UBUNTU"
	  _PKGMGR="apt-get"
	else
	    echo "Linux distro does not support"
	    exit 0
	fi 

  case $_DISTRO in
    DEBIAN|UBUNTU)
        "$_PKGMGR" update
        "$_PKGMGR" install shadowsocks-libev simple-obfs
      ;;
    *)
      echo "Linux distro does not support"
      exit 0
      ;;
  esac

	echo "{
	    \"server\":\"$_externalIP\",
	    \"server_port\":$_externalPort,
	    \"local_port\":1080,
	    \"password\":\"$_pass\",
	    \"timeout\":300,
	    \"method\":\"chacha20-ietf-poly1305\",
	    \"workers\":8,
	    \"plugin\":\"obfs-server\",
	    \"plugin_opts\": \"obfs=http;obfs-host=www.google.com\",
	    \"fast_open\":true,
	    \"reuse_port\":true
	}
	" > /etc/shadowsocks-libev/config.json
	systemctl restart shadowsocks-libev.service
	iptables -t filter -D INPUT -p tcp -d "$_externalIP" --dport "$_externalPort" -s "$_internalIP" -j ACCEPT 2>/dev/null
	iptables -t filter -I INPUT -p tcp -d "$_externalIP" --dport "$_externalPort" -s "$_internalIP" -j ACCEPT
	echo "Done"
	echo "Please get your config from /etc/shadowsocks-libev/config.json"
elif [[ "$_isInternal" ]]
then
	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/shaddowsocks_obfs.conf
	sysctl -w net.ipv4.ip_forward=1
	iptables -t filter -D INPUT -p tcp -d "$_internalIP" --dport "$_internalPort" -j ACCEPT 2>/dev/null
	iptables -t filter -D FORWARD -s "$_externalIP" -j ACCEPT 2>/dev/null
	iptables -t filter -D FORWARD -d "$_externalIP" -j ACCEPT 2>/dev/null
  iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null
	iptables -t nat -D PREROUTING -p tcp -d "$_internalIP" --dport "$_internalPort" -j DNAT --to-destination "$_externalIP":"$_externalPort" 2>/dev/null
	
	iptables -t filter -I INPUT -p tcp -d "$_internalIP" --dport "$_internalPort" -j ACCEPT
	iptables -t filter -I FORWARD -s "$_externalIP" -j ACCEPT
	iptables -t filter -I FORWARD -d "$_externalIP" -j ACCEPT
  iptables -t nat -I POSTROUTING -j MASQUERADE
	iptables -t nat -I PREROUTING -p tcp -d "$_internalIP" --dport "$_internalPort" -j DNAT --to-destination "$_externalIP":"$_externalPort"
fi
