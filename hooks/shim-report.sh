#!/usr/bin/env bash
# Shim report: when each guardrail hook last fired and how often, from the
# shim log that hooks/firelog.sh writes. A hook or event silent for the whole
# window is a candidate for removal: it either no longer happens or no longer
# needs a rule.
#
#   bash ~/.claude/hooks/shim-report.sh [days]      (default 30)
#
# "Wired" hooks are the hooks/*.sh files that call firelog; each logs under its
# own file name. Silence is only flagged once the log is older than the window.
set -u

C="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
L="$C/shim-log/fires.tsv"
days=${1:-30}
case $days in ''|*[!0-9]*) echo "usage: shim-report.sh [days]" >&2; exit 2 ;; esac

wired=$(grep -l '^[[:space:]]*[^#]*\bfirelog [a-z]' "$C"/hooks/*.sh 2>/dev/null \
        | sed 's#.*/##; s#\.sh$##' | grep -vx 'firelog\|shim-report' | tr '\n' ' ')
cutoff=$(date -d "-$days days" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -v-"$days"d +%Y-%m-%dT%H:%M:%S)

echo "Shim log: $L"
[ -s "$L" ] || { echo "No fires logged yet. Wired hooks: ${wired:-none}"; exit 0; }

awk -F'\t' -v cut="$cutoff" -v days="$days" -v wired="$wired" '
  $1 == "timestamp" || NF < 3 { next }
  { t = substr($1, 1, 19); k = $2 "\t" $3
    if (first == "" || t < first) first = t
    if (t > last[k]) last[k] = t
    if (t >= cut) { n[k]++; hn[$2]++ }
    seen[$2] = 1; keys[k] = 1 }
  END {
    old = (first < cut)
    printf "First row %s; window %d days (since %s).\n\n", substr(first, 1, 10), days, substr(cut, 1, 10)
    printf "%-20s %-14s %-17s %s\n", "hook", "event", "last fire", days "d count"
    m = 0; for (k in keys) order[++m] = k
    for (i = 2; i <= m; i++) { v = order[i]; for (j = i - 1; j >= 1 && order[j] > v; j--) order[j + 1] = order[j]; order[j + 1] = v }
    for (i = 1; i <= m; i++) {
      k = order[i]; split(k, hk, "\t"); ts = last[k]; sub(/T/, " ", ts)
      printf "%-20s %-14s %-17s %d\n", hk[1], hk[2], substr(ts, 1, 16), n[k]
      if (old && n[k] == 0) silent = silent "\n  " hk[1] " " hk[2]
    }
    w = split(wired, wl, " ")
    for (i = 1; i <= w; i++) if (!(wl[i] in hn)) {
      if (old) silent = silent "\n  " wl[i] (wl[i] in seen ? " (all events)" : " (never fired)")
      else if (!(wl[i] in seen)) young = young " " wl[i]
    }
    print ""
    if (!old) printf "Log is younger than %d days, so nothing is flagged yet.%s\n", days, (young != "" ? " Not fired yet:" young "." : "")
    else if (silent != "") printf "Silent for %d days (candidates to remove):%s\n", days, silent
    else printf "Nothing silent for %d days.\n", days
  }' "$L"
exit 0
