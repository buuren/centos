#!/bin/bash
## ===========================================================
## Some definitions:
IFACE="eth0"
IPADDR="128.199.38.203"
NAMESERVERS="8.8.4.4,8.8.8.8,209.244.0.3"
BROADCAST="128.199.63.255"
LOOPBACK="127.0.0.0/8"
CLASS_A="10.0.0.0/8"
CLASS_B="172.16.0.0/12"
CLASS_C="192.168.0.0/16"
CLASS_D_MULTICAST="224.0.0.0/4"
CLASS_E_RESERVED_NET="240.0.0.0/5"

# Disable response to ping.
/bin/echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all
# Disable response to broadcasts.
# You don't want yourself becoming a Smurf amplifier.
/bin/echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
# Don't accept source routed packets. Attackers can use source routing to generate
# traffic pretending to be from inside your network, but which is routed back along
# the path from which it came, namely outside, so attackers can compromise your
# network. Source routing is rarely used for legitimate purposes.
/bin/echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route
# Disable ICMP redirect acceptance. ICMP redirects can be used to alter your routing
# tables, possibly to a bad end.
/bin/echo "0" > /proc/sys/net/ipv4/conf/all/accept_redirects
# Enable bad error message protection.
/bin/echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses
# Turn on reverse path filtering. This helps make sure that packets use
# legitimate source addresses, by automatically rejecting incoming packets
# if the routing table entry for their source address doesn't match the network
# interface they're arriving on. This has security advantages because it prevents
# so-called IP spoofing, however it can pose problems if you use asymmetric routing
# (packets from you to a host take a different path than packets from that host to you)
# or if you operate a non-routing host which has several IP addresses on different
# interfaces. (Note - If you turn on IP forwarding, you will also get this).
for interface in /proc/sys/net/ipv4/conf/*/rp_filter; do
  /bin/echo "1" > ${interface}
done

# Log spoofed packets, source routed packets, redirect packets.
/bin/echo "1" > /proc/sys/net/ipv4/conf/all/log_martians
# Make sure that IP forwarding is turned off. We only want this for a multi-homed host.
/bin/echo "0" > /proc/sys/net/ipv4/ip_forward
## ============================================================
# RULES
iptables -F #Flush aka delete all rules in all chains
iptables -X #Delete all chains
iptables -Z #Reset counters
#default policy DROP 
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
#Allow localhost traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
#================ PROTECTION ===========================#
#Block null packets
iptables -A INPUT -i $IFACE -p tcp --tcp-flags ALL NONE -m limit --limit 5/m --limit-burst 7 -j LOG --log-prefix "TCP-IN NULL Packets "
iptables -A INPUT -i $IFACE -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -i $IFACE -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
#Block invalid packets which cannot be idetified
iptables -A INPUT -m state --state INVALID -j DROP
## SYN-FLOODING PROTECTION
# This rule maximises the rate of incoming connections. In order to do this we divert tcp
# packets with the SYN bit set off to a user-defined chain. Up to limit-burst connections
# can arrive in 1/limit seconds ..... in this case 4 connections in one second. After this, one
# of the burst is regained every second and connections are allowed again. The default limit
# is 3/hour. The default limit burst is 5.
iptables -N syn-flood
iptables -A INPUT -i $IFACE -p tcp --syn -j syn-flood
iptables -A syn-flood -m limit --limit 1/s --limit-burst 4 -j RETURN
iptables -A syn-flood -j DROP
# Drop invalid packets.
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags ACK,FIN FIN -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP
iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
## Make sure NEW tcp connections are SYN packets
iptables -A INPUT -i $IFACE -p tcp ! --syn -m state --state NEW -j DROP
## FRAGMENTS
# I have to say that fragments scare me more than anything.
# Sending lots of non-first fragments was what allowed Jolt2 to effectively "drown"
# Firewall-1. Fragments can be overlapped, and the subsequent interpretation of such
# fragments is very OS-dependent (see this paper for details).
# I am not going to trust any fragments.
# Log fragments just to see if we get any, and deny them too.
iptables -A INPUT -i $IFACE -f -j LOG --log-prefix "IPTABLES FRAGMENTS: "
iptables -A INPUT -i $IFACE -f -j DROP
iptables -A INPUT -i $IFACE -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
iptables -A INPUT -i $IFACE -p tcp --tcp-flags ALL ALL -j DROP
## SPOOFING
# Most of this anti-spoofing stuff is theoretically not really necessary with the flags we
# have set in the kernel above ........... but you never know there isn't a bug somewhere in
# your IP stack.
#
# Refuse spoofed packets pretending to be from your IP address.
iptables -A INPUT -i $IFACE -s $IPADDR -j DROP
# Refuse packets claiming to be from a Class A private network.
iptables -A INPUT -i $IFACE -s $CLASS_A -j DROP
# Refuse packets claiming to be from a Class B private network.
iptables -A INPUT -i $IFACE -s $CLASS_B -j DROP
# Refuse packets claiming to be from a Class C private network.
iptables -A INPUT -i $IFACE -s $CLASS_C -j DROP
# Refuse Class D multicast addresses. Multicast is illegal as a source address.
iptables -A INPUT -i $IFACE -s $CLASS_D_MULTICAST -j DROP
iptables -A INPUT -i $IFACE -d $CLASS_D_MULTICAST -j DROP
# Refuse Class E reserved IP addresses.
iptables -A INPUT -i $IFACE -s $CLASS_E_RESERVED_NET -j DROP
# Refuse packets claiming to be to the loopback interface.
# Refusing packets claiming to be to the loopback interface protects against
# source quench, whereby a machine can be told to slow itself down by an icmp source
# quench to the loopback.
iptables -A INPUT -i $IFACE -d $LOOPBACK -j DROP
# Refuse broadcast address packets.
iptables -A INPUT -i $IFACE -d $BROADCAST -j DROP
iptables -A INPUT -i $IFACE -m pkttype --pkt-type broadcast -j LOG --log-prefix " Broadcast "
iptables -A INPUT -i $IFACE -m pkttype --pkt-type broadcast -j DROP
 
iptables -A INPUT -i $IFACE -m pkttype --pkt-type multicast -j LOG --log-prefix " Multicast "
iptables -A INPUT -i $IFACE -m pkttype --pkt-type multicast -j DROP
#================ PROTECTION DONE =====================#

#ALLOW TCP/UDP RESPONSES
iptables -A INPUT -i $IFACE -p tcp -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i $IFACE -p udp -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p udp -m state --state NEW,ESTABLISHED -j ACCEPT
## DNS
# NOTE: DNS uses tcp for zone transfers, for transfers greater than 512 bytes (possible, but unusual), and on certain
# platforms like AIX (I am told), so you might have to add a copy of this rule for tcp if you need it
# Allow UDP packets in for DNS client from nameservers.
NAMESERVERS_ARR=$(echo $NAMESERVERS | tr "," "\n")

for NS in $NAMESERVERS_ARR; do 
	iptables -A INPUT -i $IFACE -p udp -m udp -s $NS --sport 53 -m state --state ESTABLISHED -j ACCEPT
	iptables -A INPUT -i $IFACE -p tcp -m tcp -s $NS --sport 53 -m state --state ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -o $IFACE -p udp -m udp -d $NS --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -o $IFACE -p tcp -m tcp -d $NS --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
done

## SSH
# Allow ssh outbound.
iptables -A INPUT -i $IFACE -p tcp -m tcp --dport 522 -m state --state NEW -m recent --set --name SSH_INPUT --rsource
iptables -A INPUT -i $IFACE -p tcp -m tcp --dport 522 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_INPUT --rsource -j LOG --log-prefix "SSH_INPUT" --log-level 7
iptables -A INPUT -i $IFACE -p tcp -m tcp --dport 522 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_INPUT --rsource -j DROP

iptables -A INPUT -i $IFACE -p tcp -m tcp --dport 522 -j ACCEPT
iptables -A OUTPUT -o $IFACE -p tcp -m tcp --sport 522 -j ACCEPT

## WWW/HTTP
# Allow www outbound to 80.
iptables -A INPUT -i $IFACE -p tcp --dport 8000 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $IFACE -p tcp --dport 8000 -m state --state NEW,ESTABLISHED -j ACCEPT

iptables -A INPUT -i $IFACE -p tcp --dport 8001 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $IFACE -p tcp --dport 8001 -m state --state NEW,ESTABLISHED -j ACCEPT

iptables -A INPUT -i $IFACE -p tcp -s 0/0 --sport 1024:65535 --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i $IFACE -p tcp --dport 80 -m state --state NEW -m recent --set
iptables -A INPUT -i $IFACE -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP

iptables -A OUTPUT -o $IFACE -p tcp --sport 80 -d 0/0 --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $IFACE -m owner --uid-owner nginx -p tcp --dport 80 -m state --state NEW,ESTABLISHED  -j ACCEPT
# Allow www outbound to 443.
#iptables -A INPUT -i $IFACE -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -o $IFACE -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT

# ICMP
# We accept icmp in if it is "related" to other connections (e.g a time exceeded (11)
# from a traceroute) or it is part of an "established" connection (e.g. an echo reply (0)
# from an echo-request (8)).
iptables -A INPUT -i $IFACE -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT
# We always allow icmp out.
iptables -A OUTPUT -o $IFACE -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# NTP (time)
iptables -A INPUT -s 0/0 -d 0/0 -p udp --source-port 123:123 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -s 0/0 -d 0/0 -p udp --destination-port 123:123 -m state --state NEW,ESTABLISHED -j ACCEPT

# LOGGING
# You don't have to split up your logging like I do below, but I prefer to do it this way
# because I can then grep for things in the logs more easily. One thing you probably want
# to do is rate-limit the logging. I didn't do that here because it is probably best not too
# when you first set things up ................. you actually really want to see everything going to
# the logs to work out what isn't working and why. You cam implement logging with
# "-m limit --limit 6/h --limit-burst 5" (or similar) before the -j LOG in each case.
#
# Any udp not already allowed is logged and then dropped.
iptables -A INPUT -i $IFACE -p udp -j LOG --log-prefix "IPTABLES UDP-IN: "
iptables -A INPUT -i $IFACE -p udp -j DROP
iptables -A OUTPUT -o $IFACE -p udp -j LOG --log-prefix "IPTABLES UDP-OUT: "
iptables -A OUTPUT -o $IFACE -p udp -j DROP
# Any icmp not already allowed is logged and then dropped.
iptables -A INPUT -i $IFACE -p icmp -j LOG --log-prefix "IPTABLES ICMP-IN: "
iptables -A INPUT -i $IFACE -p icmp -j DROP
iptables -A OUTPUT -o $IFACE -p icmp -j LOG --log-prefix "IPTABLES ICMP-OUT: "
iptables -A OUTPUT -o $IFACE -p icmp -j DROP
# Any tcp not already allowed is logged and then dropped.
iptables -A INPUT -i $IFACE -p tcp -j LOG --log-prefix "IPTABLES TCP-IN: "
iptables -A INPUT -i $IFACE -p tcp -j DROP
iptables -A OUTPUT -o $IFACE -p tcp -j LOG --log-prefix "IPTABLES TCP-OUT: "
iptables -A OUTPUT -o $IFACE -p tcp -j DROP
# Anything else not already allowed is logged and then dropped.
# It will be dropped by the default policy anyway ........ but let's be paranoid.
iptables -A INPUT -i $IFACE -j LOG --log-prefix "IPTABLES PROTOCOL-X-IN: "
iptables -A INPUT -i $IFACE -j DROP
iptables -A OUTPUT -o $IFACE -j LOG --log-prefix "IPTABLES PROTOCOL-X-OUT: "
iptables -A OUTPUT -o $IFACE -j DROP

service iptables save && service iptables restart
