#!/usr/bin/env bash
# Project board: one shared, append-only record per git repository that every
# Claude Code session on that repo reads and writes, so parallel chats stay in
# sync. Lives in the repo's git common dir (<repo>/.git/claude-board/), so all
# worktrees of the repo share it and it is never committed.
#
# What each session sees, injected by hooks (nothing when nothing changed):
#   SessionStart      -> other active sessions, recent notes and git activity,
#                        and a warning if another session shares this folder
#   UserPromptSubmit  -> only what OTHER sessions did since this session's last turn
#   PreToolUse (Edit) -> a note when another session edited the same file
#                        after this session last did
# What gets recorded automatically:
#   PostToolUse       -> repo-relative paths of edited files; git actions as the
#                        repo's resulting state (verb, branch, commit subject) --
#                        never the command line, so tokens in commands stay out
#   SessionEnd        -> the session leaving
# What the model records on purpose:
#   bash ~/.claude/hooks/board.sh note "decision or status, one line"
# For people:
#   bash ~/.claude/hooks/board.sh show
#
# Reading is by line-count cursor per session (<board>/cursors/<session>), so an
# entry appended while another session reads is picked up next turn, never lost.
# Hook mode always exits 0 and never blocks a tool or a prompt.
set -u
[ -n "${ROUTE_SHADOW_CHILD:-}" ] && exit 0   # route-shadow's classifier call

ACTIVE_MIN=180      # a session with no activity for this long is not listed as active
EDIT_WARN_MIN=60    # how far back another session's edit still triggers a note
MAX_SHOW=15         # update lines injected per turn; the newest are kept
MAX_ACTIVE=8        # other sessions listed at start
MODE="${1:-hook}"

now_ms() { local t; t=$(date +%s%3N 2>/dev/null); case "$t" in *N|'') echo "$(date +%s)000" ;; *) echo "$t" ;; esac; }
clean() {  # one line, at most 300 bytes, never ending inside a UTF-8 character
  local s; s=$(tr '\t\r\n' '   ')
  if [ "$(printf '%s' "$s" | LC_ALL=C wc -c)" -gt 300 ]; then
    printf '%s' "$s" | LC_ALL=C cut -b1-300 | LC_ALL=C sed 's/[\xc0-\xff][\x80-\xbf]*$//'
  else
    printf '%s' "$s"
  fi
}
# One spelling per file across Windows, Git Bash and WSL: forward slashes, and
# a drive-letter path lower-cased whole (Windows paths are case-insensitive).
npath() {
  local p; p=$(printf '%s' "$1" | sed -e 's#\\\\#/#g' -e 's#\\#/#g' -e 's#^/mnt/\([a-zA-Z]\)/#\1:/#')
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) p=$(printf '%s' "$p" | sed 's#^/\([a-zA-Z]\)/#\1:/#') ;; esac
  case "$p" in [A-Za-z]:/*) printf '%s' "$p" | tr '[:upper:]' '[:lower:]' ;; *) printf '%s' "$p" ;; esac
}
json_out() {  # json_out <hookEventName> <text>
  local e; e=$(printf '%s' "$2" | tr -d '\000-\010\013-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' |
    awk 'NR > 1 {printf "\\n"} {printf "%s", $0}')
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$e"
}
fail() { [ "$MODE" = hook ] && exit 0; echo "board.sh: $1" >&2; exit 1; }

# ---- hook mode: read the payload first, and leave early when there is nothing to do
in=""
field() { printf '%s' "$in" | tr -d '\r\n' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"\\\\]*\(\\\\.[^\"\\\\]*\)*\)\".*/\1/p" | head -1; }
EV=""; TOOL=""; CMD=""; sid=""
case "$MODE" in
hook)
  in=$(cat)
  EV=$(field hook_event_name); sid=$(field session_id)
  [ -n "$sid" ] || exit 0
  if [ "$EV" = PostToolUse ]; then
    TOOL=$(field tool_name)
    case "$TOOL" in
      Bash) CMD=$(field command)
            case "$CMD" in *board.sh*) exit 0 ;; *git*) ;; *) exit 0 ;; esac ;;
      Edit|Write|MultiEdit|NotebookEdit) ;;
      *) exit 0 ;;
    esac
  fi
  dir=$(field cwd | sed 's/\\\\/\\/g')
  cd "${dir:-${CLAUDE_PROJECT_DIR:-$PWD}}" 2>/dev/null || cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0 ;;
note|show) ;;
*) echo 'usage: board.sh [note "text" | show]' >&2; exit 1 ;;
esac

# ---- locate the repo and the board ------------------------------------------
G=$(git rev-parse --git-common-dir 2>/dev/null) || fail "not inside a git repository"
case "$G" in /*|[A-Za-z]:*) ;; *) G="$(pwd)/$G" ;; esac
RAWTOP=$(git rev-parse --show-toplevel 2>/dev/null); [ -n "$RAWTOP" ] || fail "no working tree here (bare repo, or inside .git)"
TOP=$(npath "$RAWTOP")
BR=$(git branch --show-current 2>/dev/null); : "${BR:=detached}"
B="$G/claude-board"; LOG="$B/board.tsv"; CUR="$B/cursors"
mkdir -p "$CUR" 2>/dev/null || fail "cannot create $CUR"
[ -f "$LOG" ] || : >> "$LOG"
GEN=$(cat "$B/gen" 2>/dev/null); : "${GEN:=0}"

append() {  # append <sid> <kind> <text>
  local t; t=$(printf '%s' "$3" | clean)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_ms)" "${1:0:6}" "$BR" "$TOP" "$2" "$t" >> "$LOG"
}
lines() { wc -l < "$LOG" | tr -d ' '; }
set_cursor() { printf '%s\t%s\t%s\t%s\n' "$GEN" "$2" "$BR" "$TOP" > "$CUR/$1"; }    # set_cursor <sid> <lines>
get_cursor() {  # prints the line count read so far, or nothing when unknown or stale
  local g n; [ -f "$CUR/$1" ] || return 0
  IFS=$'\t' read -r g n _ < "$CUR/$1" || return 0
  [ "$g" = "$GEN" ] && [ -n "$n" ] && printf '%s' "$n"
}
rel_path() {  # repo-relative path of a hook file path, or nothing when outside the repo
  local p; p=$(npath "$1")
  case "$p" in "$TOP"/*) printf '%s' "${p#"$TOP"/}" ;; esac
}

# Render board lines (TSV on stdin): edits collapsed per session; the newest kept.
render() {  # render <max-lines>
  awk -F'\t' -v max="$1" -v now="$(date +%s)" '
    function base(p,  n, a) { n = split(p, a, "/"); return a[n] }
    function when(ms,  s) { s = int(ms / 1000); return strftime(now - s > 43200 ? "%m-%d %H:%M" : "%H:%M", s) }
    {
      who = $2 " [" $3 " @ " base($4) "]"
      if ($5 == "edit") {
        if (!(who in files)) { order[++k] = "E" who; files[who] = ""; nf[who] = 0 }
        last[who] = $1
        if (index("," files[who] ",", "," $6 ",") == 0) { files[who] = files[who] (nf[who] ? "," : "") $6; nf[who]++ }
      } else if ($5 == "note")  order[++k] = when($1) "  " who ": " $6
      else if ($5 == "git")     order[++k] = when($1) "  " who " git " $6
      else if ($5 == "start")   order[++k] = when($1) "  " who " started"
      else if ($5 == "end")     order[++k] = when($1) "  " who " ended"
    }
    END {
      for (i = 1; i <= k; i++) {
        line = order[i]
        if (substr(line, 1, 1) == "E") {
          w = substr(line, 2); n = split(files[w], f, ","); list = ""
          for (j = 1; j <= n && j <= 5; j++) list = list (j > 1 ? ", " : "") f[j]
          if (n > 5) list = list " (+" n - 5 " more)"
          line = when(last[w]) "  " w " edited: " list
        }
        out[i] = line
      }
      first = k > max ? k - max + 1 : 1
      if (first > 1) print "- (+" first - 1 " earlier: bash ~/.claude/hooks/board.sh show)"
      for (i = first; i <= k; i++) print "- " out[i]
    }'
}

active_others() {  # lines: sid6 <tab> branch <tab> top ; newest first, at most MAX_ACTIVE
  local me="$1" f n
  for f in $(ls -t "$CUR" 2>/dev/null); do
    n="$f"; f="$CUR/$f"
    [ -f "$f" ] && [ "$n" != "$me" ] || continue
    [ -n "$(find "$f" -mmin -"$ACTIVE_MIN" 2>/dev/null)" ] || continue
    printf '%s\t%s\n' "${n:0:6}" "$(cut -f3,4 "$f" | head -1)"
  done | head -n "$MAX_ACTIVE"
}

# ---- subcommands for the model and for people --------------------------------
case "$MODE" in
note)
  shift
  [ $# -gt 0 ] || { echo 'usage: board.sh note "one line: decision, status or warning"' >&2; exit 1; }
  me="${CLAUDE_CODE_SESSION_ID:-manual}"
  append "$me" note "$*"
  [ -f "$CUR/$me" ] && touch "$CUR/$me"
  echo "noted on the project board ($B)"
  exit 0 ;;
show)
  echo "Project board: $LOG"
  echo "Active sessions (last ${ACTIVE_MIN} min):"
  active_others "${CLAUDE_CODE_SESSION_ID:-none}" | awk -F'\t' '{n = split($3, a, "/"); print "  " $1 "  on " $2 " @ " a[n]}'
  echo "Last 60 entries:"
  tail -n 60 "$LOG" | render 100
  exit 0 ;;
esac

# ---- hook mode ------------------------------------------------------------------
me6="${sid:0:6}"
case "$EV" in
SessionStart)
  find "$CUR" -type f -mtime +7 -delete 2>/dev/null        # forget sessions idle for a week
  if [ "$(lines)" -gt 4000 ]; then                           # keep the log bounded; readers resync
    if tail -n 2000 "$LOG" > "$LOG.tmp.$$" && mv -f "$LOG.tmp.$$" "$LOG" 2>/dev/null; then
      GEN=$((GEN + 1)); echo "$GEN" > "$B/gen"
    else
      rm -f "$LOG.tmp.$$"
    fi
  fi
  src=$(field source)
  c=$(get_cursor "$sid")
  if [ -z "$c" ]; then                                      # new here: start reading from now
    append "$sid" start "$src"; set_cursor "$sid" "$(lines)"
  else                                                      # clear/compact/resume: keep unread updates
    [ "$src" = resume ] && append "$sid" start resume
    touch "$CUR/$sid"
  fi
  others=$(active_others "$sid")
  day_ago=$(( $(now_ms) - 86400000 ))
  notes=$(awk -F'\t' -v me="$me6" -v t="$day_ago" '$2 != me && $1 + 0 > t + 0 && ($5 == "note" || $5 == "git")' "$LOG" | tail -n 8 | render 8)
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
  total=$(lines); c=$(get_cursor "$sid")
  set_cursor "$sid" "$total"
  [ -n "$c" ] && [ "$c" -lt "$total" ] 2>/dev/null || exit 0   # unknown cursor: resync silently
  new=$(tail -n +"$((c + 1))" "$LOG" | head -n "$((total - c))" | awk -F'\t' -v me="$me6" '$2 != me')
  [ -n "$new" ] || exit 0
  json_out UserPromptSubmit "project board: other sessions on this repo since your last turn
$(printf '%s\n' "$new" | render "$MAX_SHOW")
Treat these as facts about the repo. Re-read any file listed before you edit it."
  ;;
PreToolUse)
  fp=$(field file_path); [ -n "$fp" ] || fp=$(field notebook_path)
  rel=$(rel_path "$fp"); [ -n "$rel" ] || exit 0
  since=$(( $(now_ms) - EDIT_WARN_MIN * 60000 ))
  hit=$(tail -n 1000 "$LOG" | awk -F'\t' -v me="$me6" -v r="$rel" -v s="$since" '
    $5 == "edit" && $6 == r && $1 + 0 > s + 0 { if ($2 == me) mine = $1 + 0; else if ($1 + 0 > mine) { o = $0; om = $1 + 0 } }
    END { if (om > mine) print o }')
  [ -n "$hit" ] || exit 0
  IFS=$'\t' read -r ms who obr otop _ _ <<< "$hit"
  mins=$(( ($(now_ms) - ms) / 60000 ))
  if [ "$otop" = "$TOP" ]; then
    txt="project board: session $who edited $rel ${mins} min ago in this same folder, after you last touched it. Verify your change against the current file (re-read it) before relying on it."
  else
    txt="project board: session $who is also changing $rel on branch $obr (worktree ${otop##*/}), ${mins} min ago. Expect a merge conflict; agree who owns it with a board note or SendMessage."
  fi
  json_out PreToolUse "$txt"
  ;;
PostToolUse)
  case "$TOOL" in
    Edit|Write|MultiEdit|NotebookEdit)
      fp=$(field file_path); [ -n "$fp" ] || fp=$(field notebook_path)
      rel=$(rel_path "$fp"); [ -n "$rel" ] && append "$sid" edit "$rel" ;;
    Bash)
      c=$(printf '%s' "$CMD" | sed -e 's/\\n/; /g' -e 's/\\t/ /g' -e 's/\\"/"/g')
      verbs='commit|checkout|switch|merge|rebase|reset|pull|push|stash|cherry-pick'
      seg=$(printf '%s' "$c" | grep -oE "(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*([^[:space:];&|()]*/)?git([[:space:]]+(-[cC][[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)|--[^[:space:]]+))*[[:space:]]+($verbs)([[:space:];&|)]|\$)" | tail -1)
      verb=$(printf '%s' "$seg" | grep -oE "($verbs)([[:space:];&|)]|\$)" | tail -1 | tr -d ' ;&|)')
      [ -n "$verb" ] || exit 0
      head=$(git log -1 --format='%h %ct %s' 2>/dev/null)
      sha=${head%% *}; rest=${head#* }; ct=${rest%% *}; subj=${rest#* }
      case "$verb" in
        commit) [ -n "$ct" ] && [ $(( $(date +%s) - ct )) -lt 300 ] 2>/dev/null || exit 0
                append "$sid" git "commit $sha: $subj" ;;
        checkout|switch) append "$sid" git "$verb -> now on $BR at $sha" ;;
        push)   append "$sid" git "push ($BR at $sha)" ;;
        *)      append "$sid" git "$verb -> $BR at $sha" ;;
      esac ;;
  esac
  [ -f "$CUR/$sid" ] && touch "$CUR/$sid"
  ;;
SessionEnd)
  append "$sid" end "$(field reason)"
  rm -f "$CUR/$sid"
  ;;
esac
exit 0
