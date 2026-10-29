#!/usr/bin/env bash
# Generates monitor/alertmanager/alertmanager.yml from the template + monitor/.env
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/../monitor"

[[ -f .env ]] || { echo "Missing monitor/.env (copy .env.example)." >&2; exit 1; }
set -a; source .env; set +a

: "${TELEGRAM_CHAT_ID:?Set TELEGRAM_CHAT_ID in monitor/.env}"
[[ -s secrets/telegram_bot_token ]] || {
  echo "Put your bot token in monitor/secrets/telegram_bot_token (just the token, one line)." >&2
  exit 1
}

# Only substitute our own variable so Alertmanager's {{ }} templates are untouched.
envsubst '${TELEGRAM_CHAT_ID}' < alertmanager/alertmanager.yml.tmpl > alertmanager/alertmanager.yml

# The container runs as 'nobody'; the token file must be world-readable on this host.
chmod 0644 secrets/telegram_bot_token

echo "Wrote monitor/alertmanager/alertmanager.yml"
