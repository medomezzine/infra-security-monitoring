#!/usr/bin/env bash
# Flags processes that are (a) executing from a world-writable temp location or
# (b) named in the denylist. Needs root to read every /proc/<pid>/exe.
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib.sh"

DENYLIST="${DENYLIST:-$SCRIPT_DIR/process_denylist.conf}"

deny=()
if [[ -f "$DENYLIST" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && deny+=("$line")
  done <"$DENYLIST"
fi

tmp_exec=0
denied=0

for p in /proc/[0-9]*; do
  [[ -d "$p" ]] || continue
  exe="$(readlink "$p/exe" 2>/dev/null || true)"
  comm="$(cat "$p/comm" 2>/dev/null || true)"

  case "$exe" in
    /tmp/* | /var/tmp/* | /dev/shm/*)
      tmp_exec=$((tmp_exec + 1))
      continue
      ;;
  esac

  for name in "${deny[@]+"${deny[@]}"}"; do
    if [[ "$comm" == "$name" ]]; then
      denied=$((denied + 1))
      break
    fi
  done
done

{
  echo '# HELP security_process_anomalies Suspicious processes currently running, by reason.'
  echo '# TYPE security_process_anomalies gauge'
  echo "security_process_anomalies{reason=\"exec_from_tmp\"} ${tmp_exec}"
  echo "security_process_anomalies{reason=\"denylisted_name\"} ${denied}"
  emit_success process_anomalies
} | write_prom process_anomalies
