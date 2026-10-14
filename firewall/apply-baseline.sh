#!/bin/sh
set -eu

: "${ATTACK_IF:?ATTACK_IF must be set}"
: "${APP_IF:?APP_IF must be set}"

# Reset only rules inside this dedicated lab namespace.
iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permit only the web flow required for the exercise and its return traffic.
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i "$ATTACK_IF" -o "$APP_IF" \
  -s 172.28.10.10 -d 172.28.20.20 -p tcp --dport 80 \
  -m conntrack --ctstate NEW -j ACCEPT

# Source NAT lets DVWA return responses through the gateway without granting it
# a route back to the attacker subnet. Suricata observes the pre-NAT request.
iptables -t nat -A POSTROUTING -o "$APP_IF" \
  -s 172.28.10.0/24 -d 172.28.20.0/24 -j MASQUERADE
