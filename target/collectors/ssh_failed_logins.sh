#!/usr/bin/env bash
# Failed SSH password attempts seen in the last 5 minutes.
source "$(dirname "$(readlink -f "$0")")/lib.sh"

# The window is part of the metric name (_5m); keep both in sync.
WINDOW="5 minutes ago"

if command -v journalctl >/dev/null 2>&1 && journalctl -n 1 --no-pager -q >/dev/null 2>&1; then
  failed="$(journalctl --since "$WINDOW" --no-pager -q 2>/dev/null | grep -c 'Failed password' || true)"
else
  # Fallback without journald: approximate, last 2000 lines of auth.log
  failed="$(tail -n 2000 /var/log/auth.log 2>/dev/null | grep -c 'Failed password' || true)"
fi
failed="$(to_int "$failed")"

{
  echo '# HELP security_ssh_failed_logins_5m Failed SSH password attempts in the last 5 minutes.'
  echo '# TYPE security_ssh_failed_logins_5m gauge'
  echo "security_ssh_failed_logins_5m ${failed}"
  emit_success ssh_failed_logins
} | write_prom ssh_failed_logins
