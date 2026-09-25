#!/usr/bin/env bash
# Project board: one shared, append-only record per git repository that every
# Claude Code session on that repo reads and writes, so parallel chats stay in
# sync. Lives in the repo's git common dir (<repo>/.git/claude-board/), so all
# worktrees of the repo share it and it is never committed.
#
# What each session sees, injected by hooks (nothing when nothing changed):
#   SessionStart      -> other active sessions (branch, worktree, last note),
#                        recent notes, and a warning if another session shares
#                        this working tree
#   UserPromptSubmit  -> only what OTHER sessions did since this session's last turn
#   PreToolUse (Edit) -> a warning when another session edited the same file
#                        after this session last did
# What gets recorded automatically:
#   PostToolUse       -> files edited, and git commands that move state
#                        (commit, checkout/switch, merge, rebase, reset, pull, push, stash)
#   SessionEnd        -> the session leaving
# What the model records on purpose:
#   bash ~/.claude/hooks/board.sh note "decision or status, one line"
# For people:
#   bash ~/.claude/hooks/board.sh show
#
# Hook mode always exits 0 and never blocks a tool or a prompt.
set -u
[ -n "${ROUTE_SHADOW_CHILD:-}" ] && exit 0   # route-shadow's classifier call

ACTIVE_MIN=180      # a session with no turn for this long is not listed as active
EDIT_WARN_MIN=60    # how far back another session's edit still triggers a warning
MAX_SHOW=15         # lines of updates injected per turn before summarising

now_ms() { local t; t=$(date +%s%3N 2>/dev/null); case "$t" in *N) echo "$(date +%s)000" ;; *) echo "$t" ;; esac; }
clean() { tr '\t\r\n' '   ' | cut -c1-300; }
# One path spelling across Git Bash, WSL and Windows: forward slashes, lower-case drive.
npath() {
  printf '%s' "$1" | sed -e 's#\\\\#/#g' -e 's#\\#/#g' -e 's#^/mnt/\([a-zA-Z]\)/#\1:/#' |
    { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) sed 's#^/\([a-zA-Z]\)/#\1:/#' ;; *) cat ;; esac; } |
    sed 's#^\([A-Za-z]\):#\L\1:#'
}
json_out() {  # json_out <hookEventName> <text>
  local e; e=$(printf '%s' "$2" | tr -d '\000-\010\013-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' |
    awk 'NR > 1 {printf "\\n"} {printf "%s", $0}')
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$e"
}

# ---- locate the repo and the board ------------------------------------------
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
G=$(git rev-parse --git-common-dir 2>/dev/null) || exit 0          # not a git repo: no board
case "$G" in /*|[A-Za-z]:*) ;; *) G="$(pwd)/$G" ;; esac
B="$G/claude-board"; LOG="$B/board.tsv"; CUR="$B/cursors"
mkdir -p "$CUR" 2>/dev/null || exit 0
[ -f "$LOG" ] || : >> "$LOG"
TOP=$(npath "$(git rev-parse --show-toplevel 2>/dev/null)")
BR=$(git branch --show-current 2>/dev/null); : "${BR:=detached}"

append() {  # append <sid> <kind> <text>
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_ms)" "${1:0:6}" "$BR" "$TOP" "$2" "$(printf '%s' "$3" | clean)" >> "$LOG"
}

# Render board lines (TSV on stdin) for a reader: edits collapsed per session.
render() {
  awk -F'\t' -v max="$MAX_SHOW" '
    function wt(p,  n, a) { n = split(p, a, "/"); return a[n] }
    function hm(ms,  s) { s = int(ms / 1000); return strftime("%H:%M", s) }
    {
      who = $2 " [" $3 " @ " wt($4) "]"
      if ($5 == "edit") {
        if (!(who in files)) { order[++k] = "E" who; files[who] = "" ; nf[who] = 0 }
        last[who] = $1
        if (index("," files[who] ",", "," $6 ",") == 0) { files[who] = files[who] (nf[who] ? "," : "") $6; nf[who]++ }
      } else if ($5 == "note")  order[++k] = hm($1) "  " who ": " $6
      else if ($5 == "git")     order[++k] = hm($1) "  " who " ran: " $6
      else if ($5 == "start")   order[++k] = hm($1) "  " who " started"
      else if ($5 == "end")     order[++k] = hm($1) "  " who " ended"
    }
    END {
      shown = 0
      for (i = 1; i <= k; i++) {
        line = order[i]
        if (substr(line, 1, 1) == "E") {
          w = substr(line, 2); n = split(files[w], f, ","); list = ""
          for (j = 1; j <= n && j <= 5; j++) list = list (j > 1 ? ", " : "") f[j]
          if (n > 5) list = list " (+" n - 5 " more)"
          line = hm(last[w]) "  " w " edited: " list
        }
        if (shown < max) { print "- " line; shown++ } else extra++
      }
      if (extra) print "- (+" extra " more: bash ~/.claude/hooks/board.sh show)"
    }'
}

max_ms() { awk -F'\t' 'BEGIN{m=0} $1+0 > m {m=$1+0} END{print m}' "$LOG" 2>/dev/null; }
set_cursor() { printf '%s\t%s\t%s\n' "$2" "$BR" "$TOP" > "$CUR/$1"; }   # set_cursor <sid> <ms>
get_cursor() { cut -f1 "$CUR/$1" 2>/dev/null | head -1; }

active_others() {  # lines: sid6 <tab> branch <tab> top <tab> minutes-idle
  local me="$1" f n
  for f in "$CUR"/*; do
    [ -f "$f" ] || continue; n=$(basename "$f")
    [ "$n" = "$me" ] && continue
    [ -n "$(find "$f" -mmin -"$ACTIVE_MIN" 2>/dev/null)" ] || continue
    printf '%s\t%s\n' "${n:0:6}" "$(cut -f2,3 "$f" | head -1)"
  done
}

# ---- subcommands for the model and for people --------------------------------
case "${1:-hook}" in
note)
  shift
  [ $# -gt 0 ] || { echo 'usage: board.sh note "one line: decision, status or warning"' >&2; exit 1; }
  sid="${CLAUDE_CODE_SESSION_ID:-manual}"
  append "$sid" note "$*"
  [ -f "$CUR/$sid" ] && touch "$CUR/$sid"
  echo "noted on the project board ($B)"
  exit 0 ;;
show)
  echo "Project board: $LOG"
  echo "Active sessions (last ${ACTIVE_MIN} min):"
  active_others "${CLAUDE_CODE_SESSION_ID:-none}" | awk -F'\t' '{n = split($3, a, "/"); print "  " $1 "  on " $2 " @ " a[n]}'
  echo "Last 40 entries:"
  tail -n 40 "$LOG" 2>/dev/null | MAX_SHOW=100 render
  exit 0 ;;
hook) ;;
*) echo "usage: board.sh [note \"text\" | show]" >&2; exit 1 ;;
esac

# ---- hook mode ------------------------------------------------------------------
in=$(cat)
field() { printf '%s' "$in" | tr -d '\r\n' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"\\\\]*\(\\\\.[^\"\\\\]*\)*\)\".*/\1/p" | head -1; }
sid=$(field session_id); [ -n "$sid" ] || exit 0
me6="${sid:0:6}"

case "$(field hook_event_name)" in
SessionStart)
  # housekeeping: forget sessions idle for a week; keep the log bounded
  find "$CUR" -type f -mtime +7 -delete 2>/dev/null
  if [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 4000 ]; then
    tail -n 2000 "$LOG" > "$LOG.tmp.$$" && mv -f "$LOG.tmp.$$" "$LOG"
  fi
  src=$(field source)
  [ "$src" = "startup" ] || [ "$src" = "resume" ] || [ ! -f "$CUR/$sid" ] && append "$sid" start "$src"
  others=$(active_others "$sid")
  day_ago=$(( $(now_ms) - 86400000 ))
  notes=$(awk -F'\t' -v me="$me6" -v t="$day_ago" '$2 != me && $1 > t && ($5 == "note" || $5 == "git")' "$LOG" 2>/dev/null | tail -n 8 | render)
  set_cursor "$sid" "$(max_ms)"
  [ -z "$others" ] && [ -z "$notes" ] && exit 0
  msg="project board (shared by every Claude session on this repo; write decisions with: bash ~/.claude/hooks/board.sh note \"...\")"
  if [ -n "$others" ]; then
    msg="$msg
Other active sessions:
$(printf '%s\n' "$others" | awk -F'\t' '{n = split($3, a, "/"); print "- " $1 " on branch " $2 " @ " a[n]}')"
    if printf '%s\n' "$others" | cut -f3 | grep -qxF "$TOP"; then
      msg="$msg
WARNING: another session is working in this same folder, so edits can collide. Tell the user; for parallel code changes each chat should run in its own worktree (claude -w <name>)."
    fi
  fi
  [ -n "$notes" ] && msg="$msg
Recent notes and git activity from other sessions (24h):
$notes"
  json_out SessionStart "$msg"
  ;;
UserPromptSubmit)
  c=$(get_cursor "$sid"); : "${c:=0}"
  new=$(awk -F'\t' -v me="$me6" -v c="$c" '$1 + 0 > c + 0 && $2 != me' "$LOG" 2>/dev/null)
  set_cursor "$sid" "$(max_ms)"
  [ -n "$new" ] || exit 0
  json_out UserPromptSubmit "project board: other sessions on this repo since your last turn
$(printf '%s\n' "$new" | render)
Treat these as facts about the repo. Re-read any file listed before editing it."
  ;;
PreToolUse)
  fp=$(field file_path); [ -n "$fp" ] || fp=$(field notebook_path); [ -n "$fp" ] || exit 0
  fp=$(npath "$fp"); rel=${fp#"$TOP"/}
  since=$(( $(now_ms) - EDIT_WARN_MIN * 60000 ))
  hit=$(tail -n 1000 "$LOG" 2>/dev/null | awk -F'\t' -v me="$me6" -v r="$rel" -v s="$since" '
    $5 == "edit" && $6 == r && $1 + 0 > s + 0 { if ($2 == me) mine = $1 + 0; else if ($1 + 0 > mine) { o = $0; om = $1 + 0 } }
    END { if (om > mine) print o }')
  [ -n "$hit" ] || exit 0
  IFS=$'\t' read -r ms who obr otop _ _ <<< "$hit"
  mins=$(( ($(now_ms) - ms) / 60000 ))
  if [ "$otop" = "$TOP" ]; then
    txt="project board: session $who edited $rel ${mins} min ago in this same folder, after you last touched it. Re-read the file before editing; your copy may be stale."
  else
    txt="project board: session $who is also changing $rel on branch $obr (worktree $(basename "$otop")), ${mins} min ago. Expect a merge conflict; agree who owns it with a board note or SendMessage."
  fi
  json_out PreToolUse "$txt"
  ;;
PostToolUse)
  case "$(field tool_name)" in
    Edit|Write|MultiEdit|NotebookEdit)
      fp=$(field file_path); [ -n "$fp" ] || fp=$(field notebook_path); [ -n "$fp" ] || exit 0
      fp=$(npath "$fp"); append "$sid" edit "${fp#"$TOP"/}" ;;
    Bash)
      cmd=$(field command | sed 's/\\"/"/g')
      if printf '%s' "$cmd" | grep -qE '(^|[;&|(]|[[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(commit|checkout|switch|merge|rebase|reset|pull|push|stash|cherry-pick)([[:space:]]|$)'; then
        append "$sid" git "$(printf '%s' "$cmd" | cut -c1-160)"
      fi ;;
  esac
  [ -f "$CUR/$sid" ] && touch "$CUR/$sid"
  ;;
SessionEnd)
  append "$sid" end "$(field reason)"
  rm -f "$CUR/$sid"
  ;;
esac
exit 0
