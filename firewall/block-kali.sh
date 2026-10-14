#!/bin/sh
set -eu

ATTACK_IF="${ATTACK_IF:-$(ip -o -4 addr show | awk '$4 ~ /^172\.28\.10\./ { print $2; exit }')}"
: "${ATTACK_IF:?Run this inside the gateway container}"

# Demonstration protection: isolate the known attacker endpoint after an IDS
# alert. This is deliberately explicit rather than an automatic response.
iptables -C FORWARD -i "$ATTACK_IF" -s 172.28.10.10 -j DROP 2>/dev/null \
  || iptables -I FORWARD 1 -i "$ATTACK_IF" -s 172.28.10.10 -j DROP
