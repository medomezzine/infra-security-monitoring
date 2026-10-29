#!/usr/bin/env bash
# Runs every collector; one failing collector does not stop the others.
set -uo pipefail
DIR="$(dirname "$(readlink -f "$0")")"
rc=0
for c in ssh_failed_logins firewall_blocks process_anomalies tls_cert_expiry; do
  "$DIR/$c.sh" || { echo "collector $c failed" >&2; rc=1; }
done
exit "$rc"
