#!/bin/sh
set -eu

find_interface() {
  subnet="$1"
  ip -o -4 addr show | awk -v subnet="$subnet" '$4 ~ ("^" subnet "\\.") { print $2; exit }'
}

ATTACK_IF="$(find_interface '172.28.10')"
APP_IF="$(find_interface '172.28.20')"

if [ -z "$ATTACK_IF" ] || [ -z "$APP_IF" ]; then
  echo 'Unable to identify lab network interfaces.' >&2
  exit 1
fi

# The gateway only needs its directly connected lab subnets.  It must not act
# as a route from the exercise environment to Docker Desktop's outside network.
ip route del default 2>/dev/null || true

mkdir -p /var/log/suricata

export ATTACK_IF APP_IF
/opt/lab/firewall/apply-baseline.sh

# Suricata observes packets before the gateway performs source NAT.  The
# foreground tail keeps the container lifecycle simple; Docker's init process
# forwards shutdown signals to Suricata.
suricata \
  -T \
  -c /etc/suricata/suricata.yaml \
  -S /etc/suricata/local-rules/local.rules

suricata \
  -c /etc/suricata/suricata.yaml \
  -i "$ATTACK_IF" \
  -S /etc/suricata/local-rules/local.rules \
  -l /var/log/suricata &

touch /var/log/suricata/fast.log
sleep 1
touch /run/suricata-ready
exec tail -F /var/log/suricata/fast.log
