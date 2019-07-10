#/bin/bash

GTW='192.168.1.1'
INT='192.168.1.10'
DTC='192.168.1.20'
STG='192.168.1.30'
CLI='192.168.1.100'
EXT='200.50.100.100'
LAN='192.168.1.0/24'

#Habilita a passagem de pacotes
echo 1 > /proc/sys/net/ipv4/ip_forward

#Politicas padroes de firewall
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

#Limpa todas as chains
iptables -t nat -F
iptables -t filter -F

#Limpa a chain drop-it, se ela existir
if [-n "'iptables -L | grep drop-it' ]
	then
	    iptables -F drop-it
fi

#Limpa a chain syn-flood, se ela existir
if [ -n "'iptables -L | grep syn-flood'" ]
	then
	    iptables -F syn-flood
fi

#Limpa a chain ndrop-it, se ela existir
if [ -n "'iptables -L | grep ndrop-it'" ]
	then
	    iptables -F ndrop-it
fi

#Limpa a chains de usuarios
iptables -X

#Zera os contadores do iptables
iptables -Z

#Cria drop chains
iptables -N drop-it
#iptables -A drop-it -j LOG --log-level info
iptables -A drop-it -j REJECT

#Cria a SYN-FLOOD chain
iptables -N syn-flood

#Habilita proteçao syn-flood
iptables -A syn-flood -p tcp --syn -m limit --limit 1/s RETURN

#Habilita proteçao contra PORT SCANNERS
iptables -A syn-flood -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j RETURN

#Habilita a proteçao contra ping da morte
iptables -A syn-flood -p icmp --icmp-type echo-request -m limit --limit 1/s -J RETURN
iptables -A syn-flood -j DROP

#Cria NDROP chain
iptables -N ndrop-it

#iptables -A ndrop-it -j LOG --log-level info
iptables -A ndrop-it -j REJECT

#####################
### input session ###
#####################

# 1 - DROP pacotes oriundos de redes inválidas
iptables -A INPUT -i enp0s3 -s 192.168.0.0/16 -j drop-it
iptables -A INPUT -i enp0s3 -s 172.16.0.0/12 -j drop-it
iptables -A INPUT -i enp0s3 -s 10.0.0.0/8 -j drop-it

# 2 - Habilita o loopback
iptables -A INPUT -i lo -j ACCEPT

# 3 - Permite o retorno de conexoes estabelecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 4 - Habilita ICMP
iptables -A INPUT -p icmp -s $LAN -j ACCEPT

# 5 - Habilita o SSH do node Cliente interno
iptables -A INPUT -p tcp -s $CLI --dport 52001 -j ACCEPT


######################
### forward session ###
######################

# 1 - Habilita passagem de icmp entre LAN e Internet
iptables -A FORWARD -p icmp -s $LAN -j ACCEPT

# 2 - Permite o retorno de conexoes estabelecidas
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# 3 - Permite passagem da LAN para http e https
iptables -A FORWARD -p icmp -s $LAN --dport 80 -j ACCEPT
iptables -A FORWARD -p icmp -s $LAN --dport 443 -j ACCEPT

# 4 - Habilita passagem d LAN para DNS
iptables -A FORWARD -p udp -s $LAN --dport 53 -j ACCEPT

######################
### nat session ###
######################

#1 - Habilita o acesso a internet para a LAN
iptables -t nat -A POSTROUTING -s $LAN -o enp0s3 -j MASQUERADE
