#!/bin/sh
set -eu

ATTACK_IF="${ATTACK_IF:-$(ip -o -4 addr show | awk '$4 ~ /^172\.28\.10\./ { print $2; exit }')}"
: "${ATTACK_IF:?Run this inside the gateway container}"

while iptables -D FORWARD -i "$ATTACK_IF" -s 172.28.10.10 -j DROP 2>/dev/null; do :; done
