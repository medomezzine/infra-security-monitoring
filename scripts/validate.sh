#!/usr/bin/env bash
# Static checks using the official Prometheus image (no local promtool needed).
set -euo pipefail

ROOT="$(dirname "$(readlink -f "$0")")/.."
IMG=prom/prometheus:v2.54.1
P="$ROOT/monitor/prometheus"

run() { docker run --rm --entrypoint promtool -v "$P:/etc/prometheus:ro" "$IMG" "$@"; }

run check config /etc/prometheus/prometheus.yml
run check rules /etc/prometheus/rules/security.rules.yml
run test rules /etc/prometheus/tests/security.rules.test.yml

# Alertmanager config (needs a rendered file)
if [[ -f "$ROOT/monitor/alertmanager/alertmanager.yml" ]]; then
  docker run --rm --entrypoint amtool \
    -v "$ROOT/monitor/alertmanager/alertmanager.yml:/a.yml:ro" \
    -v "$ROOT/monitor/secrets/telegram_bot_token:/etc/alertmanager/secrets/telegram_bot_token:ro" \
    prom/alertmanager:v0.27.0 check-config /a.yml
fi
echo "All checks passed."
