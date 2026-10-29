#!/usr/bin/env bash
# Packets blocked by the firewall in the last 5 minutes, from kernel log lines
# tagged [UFW BLOCK] (ufw logging) or FW-BLOCK (custom iptables LOG prefix).
source "$(dirname "$(readlink -f "$0")")/lib.sh"

WINDOW="5 minutes ago"
PATTERN='UFW BLOCK|FW-BLOCK'

if command -v journalctl >/dev/null 2>&1 && journalctl -k -n 1 --no-pager -q >/dev/null 2>&1; then
  blocks="$(journalctl -k --since "$WINDOW" --no-pager -q 2>/dev/null | grep -cE "$PATTERN" || true)"
else
  blocks="$(tail -n 5000 /var/log/kern.log 2>/dev/null | grep -cE "$PATTERN" || true)"
fi
blocks="$(to_int "$blocks")"

{
  echo '# HELP security_firewall_blocks_5m Packets blocked by the firewall in the last 5 minutes.'
  echo '# TYPE security_firewall_blocks_5m gauge'
  echo "security_firewall_blocks_5m ${blocks}"
  emit_success firewall_blocks
} | write_prom firewall_blocks
