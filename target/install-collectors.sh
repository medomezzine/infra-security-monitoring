#!/usr/bin/env bash
# Installs the collectors + systemd timer on this VM. Run as root.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)." >&2; exit 1; }

SRC="$(dirname "$(readlink -f "$0")")"
DEST=/opt/security-collectors
TEXTFILE_DIR=/var/lib/node_exporter/textfile_collector

mkdir -p "$DEST" "$TEXTFILE_DIR"

for f in lib.sh run-all.sh ssh_failed_logins.sh firewall_blocks.sh process_anomalies.sh tls_cert_expiry.sh; do
  install -m 0755 "$SRC/collectors/$f" "$DEST/$f"
done

# Keep local edits to the config files on re-install
for f in process_denylist.conf tls_targets.conf; do
  [[ -f "$DEST/$f" ]] || install -m 0644 "$SRC/collectors/$f" "$DEST/$f"
done

install -m 0644 "$SRC/systemd/security-collectors.service" /etc/systemd/system/
install -m 0644 "$SRC/systemd/security-collectors.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now security-collectors.timer
systemctl start security-collectors.service || true

echo "Installed. Metrics files:"
ls -l "$TEXTFILE_DIR"
