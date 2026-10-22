#!/usr/bin/env bash
# Verdict ledger: makes review verdicts countable, so we can measure which
# review agent's FAILs turn out to be real bugs before cutting any of them.
#
# SubagentStop (reviewer, ui-reviewer, silent-failure-hunter): the last line
#   of the agent's final message must be
#     VERDICT: PASS|FAIL|BLOCKED findings=<n> blocking=<n> sha=<short sha>[+]|none
#   The final message is last_assistant_message, or the report in a
#   SubagentHandback call if that was the agent's last act (the desktop app's
#   background agents hand back that way). A valid line appends one row to
#   <.claude>/verdict-ledger/verdicts.tsv. A missing or malformed line blocks
#   the stop once and says why; the next stop is let through and logged as
#   MISSING, so compliance is measurable too. No readable final message at
#   all is logged as UNREAD and never blocks.
# Commands, for the main session:
#   verdict-ledger.sh list [n]                          last n rows, numbered (default 15)
#   verdict-ledger.sh outcome <row> real|false-alarm    fill in a FAIL row's outcome
#   real = at least one blocking finding was a real bug; false-alarm = none was.
#
# Why: 63 of 133 review runs (Sep 23 - Oct 20) put the verdict where no script
# could find it, so the Agents Home report counted none (observation 158).
#
# Wiring (settings.json):
#   SubagentStop, matcher "reviewer|ui-reviewer|silent-failure-hunter"
#     -> bash "$HOME/.claude/hooks/verdict-ledger.sh"
# Off switch (the hook only; the commands still work): create
# <.claude>/verdict-ledger/off
#
# The hook always exits 0 and prints nothing but a block decision.
set -u

C="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)")/.." 2>/dev/null && pwd)"
[ -n "$C" ] && [ -f "$C/hooks/verdict-ledger.sh" ] || exit 0
D="$C/verdict-ledger"
L="$D/verdicts.tsv"
AGENTS=" reviewer ui-reviewer silent-failure-hunter "
HEADER=$'timestamp\tproject\tsession\tagent\tagent_id\tsha\tverdict\tfindings\tblocking\toutcome'
USAGE="usage: verdict-ledger.sh list [n] | outcome <row> real|false-alarm"

# Lock between parallel appends and an outcome rewrite: bash's noclobber
# create is exclusive (O_EXCL). Not mkdir: WSL's uutils mkdir sometimes
# succeeds on an existing directory under contention. Windows and WSL write
# the same ledger, through WSL's hooks symlink. A lock left by a killed
# process is cleared after a minute.
lock() {
  local i
  find "$D/.lock" -maxdepth 0 -mmin +1 -delete 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do
    ( set -C; : > "$D/.lock" ) 2>/dev/null && return 0
    sleep 0.2
  done
  return 1
}
unlock() { rm -f "$D/.lock"; }

append() {  # fields in HEADER order, outcome excluded
  local IFS=$'\t' f row got=1 out=()
  for f in "$@"; do out+=("$(printf '%s' "$f" | tr '\t\r\n' '   ')"); done
  row="${out[*]}"$'\t'
  mkdir -p "$D" 2>/dev/null || return 0
  lock && got=0
  [ -s "$L" ] || printf '%s\n' "$HEADER" > "$L" 2>/dev/null
  printf '%s\n' "$row" >> "$L" 2>/dev/null
  [ $got -eq 0 ] && unlock
  return 0
}

case "${1:-}" in
list)
  n=${2:-15}
  case $n in ''|*[!0-9]*) echo "$USAGE" >&2; exit 2 ;; esac
  [ -s "$L" ] || { echo "verdict-ledger: no rows yet ($L)"; exit 0; }
  printf 'row\t%s\n' "$(head -n 1 "$L")"
  tail -n +2 "$L" | awk '{ print NR "\t" $0 }' | tail -n "$n"
  exit 0 ;;
outcome)
  row=${2:-}; val=${3:-}
  case $row in ''|0|*[!0-9]*) echo "$USAGE" >&2; exit 2 ;; esac
  case $val in real|false-alarm) ;; *) echo "$USAGE" >&2; exit 2 ;; esac
  [ -s "$L" ] || { echo "verdict-ledger: no ledger at $L" >&2; exit 1; }
  lock || { echo "verdict-ledger: ledger busy; if no review is finishing, remove $D/.lock" >&2; exit 1; }
  verdict=$(awk -F'\t' -v r=$((row + 1)) 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "verdict") c = i }
                                           NR == r { print $c }' "$L")
  if [ "$verdict" != FAIL ]; then
    unlock
    if [ -z "$verdict" ]; then echo "verdict-ledger: no row $row" >&2
    else echo "verdict-ledger: row $row is $verdict; outcomes are recorded for FAIL rows only" >&2; fi
    exit 1
  fi
  awk -F'\t' -v OFS='\t' -v r=$((row + 1)) -v v="$val" '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == "outcome") c = i }
    NR == r { $c = v } { print }' "$L" > "$L.tmp.$$" && mv "$L.tmp.$$" "$L"
  ok=$?
  rm -f "$L.tmp.$$"
  unlock
  [ $ok -eq 0 ] || { echo "verdict-ledger: could not rewrite $L" >&2; exit 1; }
  printf '%s\t%s\n' "$row" "$(sed -n "$((row + 1))p" "$L")"
  exit 0 ;;
'') [ -t 0 ] && { echo "$USAGE"; exit 0; } ;;
*) echo "$USAGE" >&2; exit 2 ;;
esac

# ---- SubagentStop hook ----
[ -e "$D/off" ] && exit 0
. "$C/hooks/firelog.sh" 2>/dev/null || firelog() { :; }   # shim log: only the blocks
in=$(cat)
field() { printf '%s' "$in" | tr -d '\r\n' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"\\\\]*\(\\\\.[^\"\\\\]*\)*\)\".*/\1/p" | head -1; }
[ "$(field hook_event_name)" = SubagentStop ] || exit 0
agent=$(field agent_type)
case "$AGENTS" in *" $agent "*) ;; *) exit 0 ;; esac
aid=$(field agent_id)
sid=$(field session_id)
[ -n "$sid" ] || exit 0
cwd=$(field cwd | sed 's/\\\\/\//g')
atp=$(field agent_transcript_path | sed 's/\\\\/\//g')
esc() { printf '%s' "$1" | tr -d '\000-\011\013-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'NR > 1 {printf "\\n"} {printf "%s", $0}'; }

# Last non-blank line of a JSON-escaped string; bold and code marks around it
# are trimmed (a fenced line is still found), anything else after it is not.
lastline() {
  printf '%s' "$1" | sed -e 's/\\r//g' -e 's/\\t/ /g' -e 's/\\n/\n/g' | tr -d '\r' \
    | sed -e 's/^[[:space:]*`]*//' -e 's/[[:space:]*`]*$//' | grep -v '^$' | tail -n 1
}

# Report text of a SubagentHandback call, if that was the agent's last act.
handback() {
  [ -n "$atp" ] && [ -f "$atp" ] || return 0
  tail -n 200 "$atp" 2>/dev/null | grep '"type":"assistant"' \
    | grep -v '"content":\[{"type":"\(redacted_\)\{0,1\}thinking"' | tail -n 1 \
    | grep '"name":"SubagentHandback"' | tr -d '\r\n' \
    | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"\\]*\(\\.[^"\\]*\)*\)".*/\1/p'
}

RE='^VERDICT: (PASS|FAIL|BLOCKED) findings=([0-9]+) blocking=([0-9]+) sha=([0-9a-f]{7,40}\+?|none)$'
why="no VERDICT line at the end"
found=""; seen=""
for text in "$(field last_assistant_message)" "$(handback)"; do
  [ -n "$text" ] || continue
  seen=1
  line=$(lastline "$text")
  if [[ ! $line =~ $RE ]]; then
    case $line in VERDICT*) why="the last line \"$line\" does not match the format" ;; esac
    continue
  fi
  v=${BASH_REMATCH[1]}; nf=$((10#${BASH_REMATCH[2]})); nb=$((10#${BASH_REMATCH[3]})); sha=${BASH_REMATCH[4]}
  if [ "$nb" -gt "$nf" ]; then why="blocking=$nb is more than findings=$nf"
  elif [ "$v" = PASS ] && [ "$nb" -gt 0 ]; then why="PASS with blocking=$nb (a blocking finding means FAIL)"
  elif [ "$v" = FAIL ] && [ "$nb" -eq 0 ]; then why="FAIL with blocking=0 (FAIL needs at least one blocking finding)"
  else found=1; break
  fi
done

proj=""
if [ -n "$cwd" ]; then
  gd=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  [ -n "$gd" ] && proj=$(basename "$(dirname "$gd")")
  [ -n "$proj" ] || proj=$(basename "$cwd")
fi
now=$(date '+%Y-%m-%dT%H:%M:%S%z')
# Marks an agent the hook has just sent back. It lives only until that
# agent's next stop, so an agent continued later (SendMessage) is asked again.
# Docs promise agent_id; without it, session + agent type stand in.
mark="$D/asked/${aid:-$sid-$agent}"

if [ -n "$found" ]; then
  rm -f "$mark" 2>/dev/null
  append "$now" "$proj" "$sid" "$agent" "$aid" "$sha" "$v" "$nf" "$nb"
  exit 0
fi
# No text from either source (no last_assistant_message, transcript missing
# or not yet written): the hook is blind, not the agent wrong. Log, don't block.
if [ -z "$seen" ]; then
  append "$now" "$proj" "$sid" "$agent" "$aid" "" "UNREAD" "" ""
  exit 0
fi

# Block once. stop_hook_active covers the documented case; the mark makes
# sure a second block in a row can never happen even if that flag is not set.
if printf '%s' "$in" | tr -d '\r\n' | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' \
   || [ -e "$mark" ]; then
  rm -f "$mark" 2>/dev/null
  append "$now" "$proj" "$sid" "$agent" "$aid" "" "MISSING" "" ""
  exit 0
fi
mkdir -p "$D/asked" 2>/dev/null && : > "$mark" 2>/dev/null
find "$D/asked" -type f -mtime +2 -delete 2>/dev/null
firelog verdict-ledger block "$agent"
printf '{"decision":"block","reason":"%s"}\n' "$(esc "verdict-ledger hook: $why. Your final message must end with the verdict line, alone and in plain text:
VERDICT: <PASS|FAIL|BLOCKED> findings=<n> blocking=<n> sha=<short sha>
PASS = no blocking finding, FAIL = at least one, BLOCKED = could not finish the review. findings = everything you reported; blocking = what must be fixed before the change is accepted. sha = git rev-parse --short HEAD of the code you reviewed, with + added if you reviewed uncommitted changes, or none outside a git repo.
Send your full report again, unchanged, with that line as its very last line and nothing after it. Do not redo the review.")"
exit 0
