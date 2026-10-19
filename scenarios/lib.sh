#!/bin/sh
# Shared helpers for scripts executed from the isolated Kali container.
set -eu

DVWA_URL="${DVWA_URL:-http://172.28.20.20}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/home/kali/evidence}"

new_run() {
    scenario="$1"
    run_id="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
    RUN_DIR="$EVIDENCE_ROOT/${run_id}-${scenario}"
    mkdir -p "$RUN_DIR"
    export RUN_DIR
    printf '%s\n' "$DVWA_URL" > "$RUN_DIR/target.txt"
    date -u +%FT%TZ > "$RUN_DIR/started-at.txt"
}

dvwa_curl() {
    # A protected replay must fail promptly rather than leaving the demo hung.
    curl --connect-timeout 3 --max-time 10 "$@"
}

token_from() {
    sed -n "s/.*name='user_token' value='\([^']*\)'.*/\1/p" "$1" | head -n 1
}

require_token() {
    token="$(token_from "$1")"
    if [ -z "$token" ]; then
        echo "Unable to obtain the DVWA CSRF token from $1." >&2
        exit 1
    fi
    printf '%s' "$token"
}

login_as_admin_low() {
    cookie_file="$RUN_DIR/cookies.txt"

    dvwa_curl --fail --silent --show-error --cookie-jar "$cookie_file" \
        "$DVWA_URL/login.php" -o "$RUN_DIR/login-form.html"
    token="$(require_token "$RUN_DIR/login-form.html")"

    dvwa_curl --fail --silent --show-error --cookie "$cookie_file" \
        --cookie-jar "$cookie_file" --data-urlencode 'username=admin' \
        --data-urlencode 'password=password' --data-urlencode 'Login=Login' \
        --data-urlencode "user_token=$token" "$DVWA_URL/login.php" \
        -D "$RUN_DIR/login-headers.txt" -o "$RUN_DIR/login-response.html"

    if ! grep -qi '^Location: index.php' "$RUN_DIR/login-headers.txt"; then
        echo 'DVWA login failed; initialise the lab with 00-init-dvwa.sh first.' >&2
        exit 1
    fi

    dvwa_curl --fail --silent --show-error --cookie "$cookie_file" \
        --cookie-jar "$cookie_file" "$DVWA_URL/security.php" \
        -o "$RUN_DIR/security-form.html"
    token="$(require_token "$RUN_DIR/security-form.html")"

    dvwa_curl --fail --silent --show-error --cookie "$cookie_file" \
        --cookie-jar "$cookie_file" --data-urlencode 'security=low' \
        --data-urlencode 'seclev_submit=Submit' --data-urlencode "user_token=$token" \
        "$DVWA_URL/security.php" -D "$RUN_DIR/security-headers.txt" \
        -o "$RUN_DIR/security-response.html"

    dvwa_curl --fail --silent --show-error --cookie "$cookie_file" \
        "$DVWA_URL/security.php" -o "$RUN_DIR/security-low.html"
    if ! grep -q 'Security level is currently: <em>low</em>' "$RUN_DIR/security-low.html"; then
        echo 'DVWA security level could not be set to low.' >&2
        exit 1
    fi
}
