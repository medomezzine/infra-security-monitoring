#!/usr/bin/env bash
# Shared helpers for the node-exporter textfile collectors.
set -euo pipefail

OUT_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
mkdir -p "$OUT_DIR"

# write_prom <name>: read metrics on stdin, publish atomically as <name>.prom
# (node-exporter only reads *.prom, so the dot-prefixed temp file is ignored).
write_prom() {
  local name="$1" tmp
  tmp="$(mktemp "${OUT_DIR}/.${name}.XXXXXX")"
  cat >"$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "${OUT_DIR}/${name}.prom"
}

# emit_success <collector>: freshness metric, lets you alert on stale collectors
emit_success() {
  echo '# HELP security_collector_last_success_timestamp_seconds Unix time of the last successful collector run.'
  echo '# TYPE security_collector_last_success_timestamp_seconds gauge'
  echo "security_collector_last_success_timestamp_seconds{collector=\"$1\"} $(date +%s)"
}

# to_int <value>: fall back to 0 if not a plain integer
to_int() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then echo "$1"; else echo 0; fi
}
