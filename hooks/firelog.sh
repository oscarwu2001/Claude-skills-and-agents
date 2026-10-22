# Shim log: every hook that injects or blocks something records one line when
# it fires, so a guardrail that has stopped firing shows up and can be removed
# (the "track shims centrally" idea from Cursor's talk "Is the harness dead?").
#
# Sourced, not run, so sourcing starts no process (Git Bash forks are slow):
#   . "$C/hooks/firelog.sh" 2>/dev/null || firelog() { :; }
#   firelog <hook> <event> [detail]
# Appends  timestamp <tab> hook <tab> event <tab> detail  to
# <.claude>/shim-log/fires.tsv, which is never tracked. The detail is a count, a
# size or a name, never prompt text: callers pass only what they computed.
# Report: bash ~/.claude/hooks/shim-report.sh
#
# Never prints, always returns 0 (safe under set -e and set -u).

# This file's folder, made absolute now, so a caller that changes folder later
# still logs to the same place.
_firelog_hooks=${BASH_SOURCE[0]%/*}
case $_firelog_hooks in /*|[A-Za-z]:*) ;; *) _firelog_hooks=$PWD/$_firelog_hooks ;; esac

firelog() {
  # Resolved on first use, next to the real hooks folder (cd -P follows a WSL
  # link to the Windows one).
  [ -n "${_firelog_tsv-}" ] || _firelog_tsv="$(cd -P "$_firelog_hooks/.." 2>/dev/null && pwd)/shim-log/fires.tsv"
  local d=${_firelog_tsv%/*} detail=${3-}
  [ -n "${1-}" ] && [ -n "${2-}" ] && [ "$d" != /shim-log ] || return 0
  [ -d "$d" ] || mkdir -p "$d" 2>/dev/null || return 0
  # 2>/dev/null goes first so a failed open (read-only, locked in Excel) is silent too.
  [ -s "$_firelog_tsv" ] || printf 'timestamp\thook\tevent\tdetail\n' 2>/dev/null >> "$_firelog_tsv" || :
  detail=${detail//[$'\t\r\n']/ }
  printf '%(%Y-%m-%dT%H:%M:%S%z)T\t%s\t%s\t%s\n' -1 "$1" "$2" "${detail:0:120}" 2>/dev/null >> "$_firelog_tsv" || :
  return 0
}
