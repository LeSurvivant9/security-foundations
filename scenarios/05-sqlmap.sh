#!/bin/sh
# Run a bounded sqlmap detection against DVWA only; never enumerate or dump data.
set -eu
. /opt/scenarios/lib.sh

new_run sqlmap
login_as_admin_low

cookie_file="$RUN_DIR/cookies.txt"
php_session="$(awk '$6 == "PHPSESSID" { print $7; exit }' "$cookie_file")"
security_level="$(awk '$6 == "security" { print $7; exit }' "$cookie_file")"

if [ -z "$php_session" ] || [ -z "$security_level" ]; then
    echo 'DVWA session cookies are unavailable for the authorised sqlmap replay.' >&2
    exit 1
fi

# Boolean-based testing is sufficient to establish the intentionally vulnerable
# parameter.  Do not add enumeration or extraction options to this scenario.
target_url="$DVWA_URL/vulnerabilities/sqli/?id=1&Submit=Submit"
cookie_header="security=${security_level}; PHPSESSID=${php_session}"
output_dir="$RUN_DIR/sqlmap-output"

if ! sqlmap -u "$target_url" --cookie="$cookie_header" --batch \
    --technique=B --level=1 --risk=1 --output-dir="$output_dir" \
    > "$RUN_DIR/sqlmap-output.txt" 2>&1; then
    cat "$RUN_DIR/sqlmap-output.txt" >&2
    exit 1
fi

if ! grep -Eqi "parameter 'id' is vulnerable|sqlmap identified the following injection point" \
    "$RUN_DIR/sqlmap-output.txt"; then
    cat "$RUN_DIR/sqlmap-output.txt" >&2
    echo 'sqlmap did not confirm the expected DVWA SQL injection.' >&2
    exit 1
fi

printf '%s\n' 'sqlmap confirmed the controlled DVWA SQL injection without enumerating data. Evidence: '"$RUN_DIR"
