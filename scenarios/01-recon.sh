#!/bin/sh
# Perform the limited, authorised service discovery used in the report.
set -eu
. /opt/scenarios/lib.sh

new_run recon
target_ip="${DVWA_URL#http://}"
target_ip="${target_ip%%/*}"

dvwa_curl --fail --silent --show-error --head "$DVWA_URL/" \
    > "$RUN_DIR/http-headers.txt"
nmap -Pn -sT -sV -p 80,3306 "$target_ip" \
    -oN "$RUN_DIR/nmap-dvwa.txt"

printf '%s\n' "Reconnaissance complete. Evidence: $RUN_DIR"
