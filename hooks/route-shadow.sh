#!/usr/bin/env bash
# Shadow-mode router: a cheap, fast model classifies each request into a work
# mode with a calibrated confidence, and the route the main model actually took
# is logged beside it. Nothing is injected and nothing is blocked -- this only
# collects evidence for whether a confidence-gated router would help.
# (The System One / Jev pattern: fast typed decision + confidence, act only
# when sure, escalate otherwise. Here, step one: watch before acting.)
#
# Wiring (settings.json), one script for both events:
#   UserPromptSubmit                     -> logs the prompt boundary, classifies in the background
#   PreToolUse, matcher "Skill|Agent|Task" -> logs the route actually taken
# Report: python3 ~/.claude/hooks/route-shadow-report.py
#
# Log: <.claude>/route-shadow/log.jsonl -- ids, times, modes, confidences and
# route names only; never prompt text. Gitignored by the allowlist.
# Off switch: create <.claude>/route-shadow/off
#
# Always exits 0 with no stdout, so it can never change or block a turn.
set -u
[ -n "${ROUTE_SHADOW_CHILD:-}" ] && exit 0   # the classifier's own claude -p

C="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)")/.." 2>/dev/null && pwd)"
[ -n "$C" ] && [ -f "$C/hooks/route-shadow.sh" ] || exit 0
D="$C/route-shadow"
[ -e "$D/off" ] && exit 0
mkdir -p "$D" 2>/dev/null || exit 0
LOG="$D/log.jsonl"

in=$(cat)
field() {  # first "key":"value" string in the hook JSON, still JSON-escaped
  printf '%s' "$in" | tr -d '\r\n' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"\\\\]*\(\\\\.[^\"\\\\]*\)*\)\".*/\1/p" | head -1
}
now() { date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ; }
sid=$(field session_id)

case "$(field hook_event_name)" in
UserPromptSubmit)
  pid="$(date +%s)-$$-$RANDOM"
  printf '{"ts":"%s","session":"%s","event":"prompt","pid":"%s"}\n' "$(now)" "$sid" "$pid" >> "$LOG"
  command -v claude >/dev/null 2>&1 || exit 0
  modes='research|deep-research|codebase-analysis|data-analysis|review|docs|planning|coding|bug|skill-meta|chat'
  schema='{"type":"object","properties":{"mode":{"type":"string","enum":["'"${modes//|/\",\"}"'"]},"confidence":{"type":"number","minimum":0,"maximum":1}},"required":["mode","confidence"]}'
  sys='You route requests for a coding assistant. Pick the ONE mode that should handle the request:
research = one precise question about a library, API, spec or best practice, answered from docs
deep-research = broad multi-source report: a market, literature, or comparison of options in a field
codebase-analysis = understand how this codebase works, find where something lives, map or diagram it
data-analysis = run experiments, sweeps, metrics or analyses over data
review = review a branch, PR, diff or recent change
docs = write or update README, guides, API reference, docstrings, changelog
planning = shape an idea or design, write a spec, split work into tickets, plan a large effort
coding = implement specified work or make a concrete change
bug = something is broken or failing and the cause is not yet known
skill-meta = the assistant configuration itself: skills, agents, hooks, CLAUDE.md
chat = a question answerable in conversation with no project work
confidence = your calibrated probability that the mode is right: 0.9 means right 9 times in 10. Use low values when the request is ambiguous or spans modes.'
  (
    out=$(cd "${TMPDIR:-/tmp}" && printf 'Classify the request in the "prompt" field of this hook payload:\n%s' "$in" |
      ROUTE_SHADOW_CHILD=1 timeout 60 claude -p --model haiku --tools "" --max-turns 2 \
        --no-session-persistence --output-format json \
        --system-prompt "$sys" --json-schema "$schema" 2>/dev/null)
    so=$(printf '%s' "$out" | tr -d '\r\n' | sed -n 's/.*"structured_output"[[:space:]]*:[[:space:]]*\({[^}]*}\).*/\1/p')
    cost=$(printf '%s' "$out" | sed -n 's/.*"total_cost_usd"[[:space:]]*:[[:space:]]*\([0-9.eE-]*\).*/\1/p' | head -1)
    [ -n "$so" ] || so='{"mode":"error","confidence":0}'
    printf '{"ts":"%s","session":"%s","event":"shadow","pid":"%s","decision":%s,"cost_usd":%s}\n' \
      "$(now)" "$sid" "$pid" "$so" "${cost:-0}" >> "$LOG"
  ) </dev/null >/dev/null 2>&1 &
  ;;
PreToolUse)
  tool=$(field tool_name)
  case "$tool" in
    Skill)      name=$(field skill) ;;
    Agent|Task) name=$(field subagent_type); : "${name:=general-purpose}" ;;
    *)          exit 0 ;;
  esac
  printf '{"ts":"%s","session":"%s","event":"route","tool":"%s","name":"%s"}\n' "$(now)" "$sid" "$tool" "$name" >> "$LOG"
  ;;
esac
exit 0
