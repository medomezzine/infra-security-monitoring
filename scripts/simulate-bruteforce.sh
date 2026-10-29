#!/usr/bin/env bash
# Lab test: generate failed SSH logins against YOUR OWN target VM with hydra,
# to prove the chain  collector -> Prometheus -> Alertmanager -> Telegram.
# Usage: scripts/simulate-bruteforce.sh <target-ip> [username]
set -euo pipefail

TARGET="${1:?Usage: $0 <target-ip> [username]}"
USER_NAME="${2:-labuser}"

command -v hydra >/dev/null || { echo "Install hydra first: sudo apt install hydra" >&2; exit 1; }

echo "This will send ~40 failed SSH login attempts to ${TARGET} as '${USER_NAME}'."
echo "Only run it against machines you own and are allowed to test."
read -r -p "Type the target IP again to confirm: " confirm
[[ "$confirm" == "$TARGET" ]] || { echo "Aborted."; exit 1; }

WORDLIST="$(mktemp)"
trap 'rm -f "$WORDLIST"' EXIT
for i in $(seq 1 40); do echo "wrong-password-$i"; done >"$WORDLIST"

hydra -l "$USER_NAME" -P "$WORDLIST" -t 4 "ssh://${TARGET}" || true

echo
echo "Done. Within ~1-2 minutes expect SSHBruteForceDetected to go pending, then firing."
echo "Check: http://localhost:9090/alerts (SSH tunnel) and your Telegram chat."
