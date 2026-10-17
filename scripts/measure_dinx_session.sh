#!/usr/bin/env bash
set -euo pipefail

if ! command -v ps >/dev/null 2>&1; then
  printf 'dinx_session_measurement unavailable=ps\n'
  exit 0
fi

printf 'dinx_session_measurement source=procfs snapshot=true\n'
for process in mango noctalia bc250-control-centerd dinx-idle swayidle; do
  read -r count rss cpu <<EOF
$(ps -eo comm=,rss=,%cpu= | awk -v target="$process" '$1 == target {count++; rss += $2; cpu += $3} END {printf "%d %d %.2f", count + 0, rss + 0, cpu + 0}')
EOF
  if (( count == 0 )); then
    printf 'process=%s state=absent rss_kib=0 cpu_percent=0.00\n' "$process"
  else
    printf 'process=%s state=present instances=%s rss_kib=%s cpu_percent=%s\n' "$process" "$count" "$rss" "$cpu"
  fi
done
