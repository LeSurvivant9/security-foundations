#!/bin/sh
set -eu

# The Docker bridge gateway is the default route.  The application subnet must
# instead be reached through the IDS/firewall container.
ip route del default 2>/dev/null || true
ip route replace 172.28.20.0/24 via 172.28.10.254

exec sleep infinity
