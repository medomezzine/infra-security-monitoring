#!/usr/bin/env bash
# Seconds until the TLS certificate of each host:port in tls_targets.conf expires.
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib.sh"

TARGETS="${TLS_TARGETS:-$SCRIPT_DIR/tls_targets.conf}"
OUT="${OUT_DIR}/tls_cert_expiry.prom"
MAX_AGE="${TLS_MAX_AGE:-3600}"   # certs change slowly: probe at most hourly

if [[ -f "$OUT" ]] && (( $(date +%s) - $(stat -c %Y "$OUT") < MAX_AGE )); then
  exit 0
fi

now="$(date +%s)"
body=""

if [[ -f "$TARGETS" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] && continue
    [[ "$line" == *:* ]] || line="${line}:443"
    host="${line%%:*}"

    end="$(timeout 10 openssl s_client -servername "$host" -connect "$line" </dev/null 2>/dev/null \
      | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2- || true)"

    if [[ -n "$end" ]] && ts="$(date -d "$end" +%s 2>/dev/null)"; then
      body+="security_tls_cert_expiry_seconds{target=\"${line}\"} $((ts - now))"$'\n'
      body+="security_tls_cert_probe_success{target=\"${line}\"} 1"$'\n'
    else
      body+="security_tls_cert_probe_success{target=\"${line}\"} 0"$'\n'
    fi
  done <"$TARGETS"
fi

{
  echo '# HELP security_tls_cert_expiry_seconds Seconds until the TLS certificate expires (negative = expired).'
  echo '# TYPE security_tls_cert_expiry_seconds gauge'
  echo '# HELP security_tls_cert_probe_success Whether the TLS probe could read a certificate.'
  echo '# TYPE security_tls_cert_probe_success gauge'
  printf '%s' "$body"
  emit_success tls_cert_expiry
} | write_prom tls_cert_expiry
