#!/bin/bash

CLIENT_IP='172.28.54.66'
SERVER_IP='172.28.54.135'

iptables -F
iptables -X

iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

iptables -A INPUT -p tcp -s $CLIENT_IP -d $SERVER_IP --sport 513:65535 --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp -s $SERVER_IP -d $CLIENT_IP --sport 22 --dport 513:65535 -m state --state ESTABLISHED -j ACCEPT

iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

iptables -A INPUT -j DROP
iptables -A OUTPUT -j DROP
