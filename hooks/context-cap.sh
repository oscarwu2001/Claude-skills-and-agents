#!/usr/bin/env bash
# Context cap: stops a main session from re-reading a huge context on every
# turn by pushing it to hand off to a fresh session, through a file.
#
# UserPromptSubmit: reads the last assistant turn's usage from the session
#   transcript (input + cache write + cache read + output = what the next turn
#   re-reads). Past SOFT it nudges for a handoff, once per 50K band; past HARD
#   it insists on every prompt. The handoff file goes under
#   <.claude>/handoffs/<project>/, named by date and session.
# SessionStart (startup or /clear only): points the new session at the newest
#   handoff for its project that is under 14 days old and not yet picked up
#   (picked up = renamed to *.done.md).
#
# Why: Sep 23 - Oct 20, 90% of main-session turns ran above 120K context, one
# session averaged 494K over 2,229 turns, and cache re-reads were 76% of
# main-session cost. The CLAUDE.md handoff rule alone never fired.
#
# Wiring (settings.json), one script for both events:
#   UserPromptSubmit, SessionStart -> bash "$HOME/.claude/hooks/context-cap.sh"
# Thresholds in tokens: CONTEXT_CAP_SOFT (default 200000), CONTEXT_CAP_HARD
# (default 400000). Off switch: create <.claude>/context-cap/off
#
# Always exits 0. Prints nothing below the soft line or when unsure.
set -u

C="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)")/.." 2>/dev/null && pwd)"
[ -n "$C" ] && [ -f "$C/hooks/context-cap.sh" ] || exit 0
[ -e "$C/context-cap/off" ] && exit 0
SOFT=${CONTEXT_CAP_SOFT:-200000}
HARD=${CONTEXT_CAP_HARD:-400000}
case $SOFT in ''|*[!0-9]*) SOFT=200000 ;; esac
case $HARD in ''|*[!0-9]*) HARD=400000 ;; esac

in=$(cat)
field() { printf '%s' "$in" | tr -d '\r\n' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"\\\\]*\(\\\\.[^\"\\\\]*\)*\)\".*/\1/p" | head -1; }
ev=$(field hook_event_name)
sid=$(field session_id)
tp=$(field transcript_path | sed 's/\\\\/\//g')   # JSON's escaped backslashes -> /
{ [ -n "$sid" ] && [ -n "$tp" ]; } || exit 0

proj=$(basename "$(dirname "$tp")")
H="$C/handoffs/$proj"
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
esc() { printf '%s' "$1" | tr -d '\000-\011\013-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'NR > 1 {printf "\\n"} {printf "%s", $0}'; }
emit() {  # $1 event, $2 line shown to the user, $3 context for the model
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
    "$(esc "$2")" "$1" "$(esc "$3")"
}

case "$ev" in
SessionStart)
  case "$(field source)" in startup|clear) ;; *) exit 0 ;; esac
  newest=$(ls -t "$H"/*.md 2>/dev/null | grep -v '\.done\.md$' | head -n 1)
  [ -n "$newest" ] && [ -n "$(find "$newest" -mtime -14 2>/dev/null)" ] || exit 0
  p=$(winpath "$newest")
  emit SessionStart "Handoff waiting: $(basename "$newest")" \
"context-cap: a handoff from an earlier session in this project is waiting at $p (last written $(date -r "$newest" '+%Y-%m-%d %H:%M')).
If the user's first request continues that work, read the handoff before anything else, then rename it to end in .done.md so later sessions are not pointed at it again. If the request is unrelated, ignore it and do not mention it again."
  exit 0 ;;
UserPromptSubmit) ;;
*) exit 0 ;;
esac

[ -f "$tp" ] || exit 0

# Context of the last assistant turn with a non-zero usage (skips sidechain
# lines and zero-usage placeholders). The last match per key on the line is
# the message's own usage; text inside content strings is escaped, so it
# never matches these unescaped keys.
ctx=0
for n in 400 4000; do
  ctx=$(tail -n "$n" "$tp" 2>/dev/null | grep '"type":"assistant"' | grep '"usage"' \
        | grep -v '"isSidechain":true' | tail -n 5 | awk '
    function last(s, k,   p, n) { n = split(s, p, "\"" k "\":"); return n > 1 ? p[n] + 0 : 0 }
    { t = last($0, "input_tokens") + last($0, "cache_creation_input_tokens") \
        + last($0, "cache_read_input_tokens") + last($0, "output_tokens")
      if (t > 0) r = t }
    END { print r + 0 }')
  [ "${ctx:-0}" -gt 0 ] && break
done
ctx=${ctx:-0}
[ "$ctx" -ge "$SOFT" ] || exit 0

k=$((ctx / 1000))
mkdir -p "$H" "$C/context-cap/state" 2>/dev/null
f=$(winpath "$H/$(date +%Y-%m-%d)-${sid:0:8}.md")
what="A handoff holds: the goal; the plan, marked done and next; decisions and why; files, branches and commits touched; helpers still running and what each is doing; open questions; the exact next step. Point at existing plan, spec or ledger files by path instead of copying them. Redact secrets and personal identifiers."

if [ "$ctx" -ge "$HARD" ]; then
  emit UserPromptSubmit "Context ${k}K, past the $((HARD / 1000))K cap: handoff required (context-cap hook)" \
"context-cap: this session's context is ${k}K tokens, past the $((HARD / 1000))K cap, and every turn re-reads all of it.
Before other work this turn: tell the user in one line, bring the current step to a safe stop (no half-finished edit), write the handoff to $f, and ask the user to /clear or open a new session in this project; the new session is pointed at the file automatically. If the user has already said in this session to carry on past the cap, say the size in one line and continue.
$what"
  exit 0
fi

# Soft: once per 50K band per session. A smaller band (after /compact)
# lowers the mark, so growth past the line nudges again.
st="$C/context-cap/state/$sid"
band=$((ctx / 50000))
last=$(cat "$st" 2>/dev/null)
case $last in ''|*[!0-9]*) last=0 ;; esac
if [ "$band" -le "$last" ]; then
  [ "$band" -lt "$last" ] && printf '%s\n' "$band" > "$st"
  exit 0
fi
printf '%s\n' "$band" > "$st"
find "$C/context-cap/state" -type f -mtime +14 -delete 2>/dev/null
emit UserPromptSubmit "Context ${k}K: handoff suggested at the next stopping point (context-cap hook)" \
"context-cap: this session's context is ${k}K tokens, past the $((SOFT / 1000))K handoff line, and every turn re-reads all of it.
At the next natural stopping point (not mid-edit), write a handoff to $f and suggest the user /clear or open a new session in this project; the new session is pointed at the file automatically.
$what"
exit 0
