#!/bin/sh
# Reset the deliberately vulnerable DVWA database for a reproducible lab run.
set -eu
. /opt/scenarios/lib.sh

new_run init
cookie_file="$RUN_DIR/cookies.txt"

printf '%s\n' 'Waiting for DVWA setup page…'
attempt=1
while ! dvwa_curl --fail --silent --show-error --cookie-jar "$cookie_file" \
    "$DVWA_URL/setup.php" -o "$RUN_DIR/setup-form.html"; do
    if [ "$attempt" -ge 12 ]; then
        echo 'DVWA did not become available in time.' >&2
        exit 1
    fi
    attempt=$((attempt + 1))
    sleep 2
done

token="$(require_token "$RUN_DIR/setup-form.html")"
dvwa_curl --fail --silent --show-error --location --cookie "$cookie_file" --cookie-jar "$cookie_file" \
    --data-urlencode 'create_db=Create / Reset Database' \
    --data-urlencode "user_token=$token" "$DVWA_URL/setup.php" \
    -o "$RUN_DIR/setup-result.html"

if ! grep -q 'Database has been created' "$RUN_DIR/setup-result.html"; then
    echo 'DVWA database reset did not report success.' >&2
    exit 1
fi

login_as_admin_low
printf '%s\n' "DVWA reset and configured at low security. Evidence: $RUN_DIR"
