#!/usr/bin/env bash
# SessionStart hook: task-observer's Session Start Protocol, computed by the
# harness instead of by the model, and injected as a short brief.
#
# Why a hook: the protocol's steps 1-3 and 6 are file checks (make the storage,
# scan frontmatter, compare a date, resolve skill names). Asking the model to do
# them meant loading the full 33 KB skill before every session's first tool
# call, and a skipped step was invisible. Here they run every session for free,
# and the full skill is loaded only when there is something to log or review.
#
# Wiring: settings.json -> hooks.SessionStart -> bash ~/.claude/hooks/observer-brief.sh
# The workspace is the .claude folder that holds this script (symlinks resolved,
# so a WSL link lands on the Windows folder) -- never the cwd.
#
# Never fails the session: any problem is reported inside the brief, exit 0.
set -u

C="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
W="$C/skill-observations"
L="$W/observation-log"
notes=()

# Step 1: storage. Principles file needs the skill's template, so it is only reported.
if [ -f "$W/log.md" ] && [ ! -d "$L" ]; then
  notes+=("LEGACY single-file log found: load task-observer and run references/migration.md before logging anything.")
else
  mkdir -p "$L/archive" 2>/dev/null || notes+=("Could not create $L -- report this, do not log elsewhere.")
  [ -f "$W/last-review-date.txt" ] || echo never > "$W/last-review-date.txt"
  [ -f "$W/cross-cutting-principles.md" ] || notes+=("cross-cutting-principles.md missing: create it from task-observer references/skill-authoring.md on first write.")
fi

# Step 2: frontmatter-only scan, with the broken-parse guard.
n=0; parsed=0; open=0; parked=0; targets=""; open_targets=""
for f in "$L"/*.md; do
  [ -e "$f" ] || continue
  n=$((n + 1))
  hdr=$(awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next} fm && /^---[[:space:]]*$/ {exit} fm' "$f")
  [ -n "$hdr" ] || continue
  parsed=$((parsed + 1))
  st=$(printf '%s\n' "$hdr" | awk -F: '/^status:/ {sub(/#.*/, "", $2); gsub(/[[:space:]]/, "", $2); print $2; exit}')
  # skill: [a, b] | skill: a | skill:\n  - a
  sk=$(printf '%s\n' "$hdr" | awk '
    /^skill:/ { s=$0; sub(/^skill:[[:space:]]*/, "", s); sub(/#.*/, "", s); gsub(/[][,"\047]/, " ", s); print s; blk=1; next }
    blk && /^[[:space:]]*-/ { s=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", s); gsub(/["\047]/, "", s); print s; next }
    { blk=0 }')
  targets="$targets $sk"
  case "$st" in
    parked) parked=$((parked + 1)) ;;
    actioned|declined|superseded) ;;
    *) open=$((open + 1)); open_targets="$open_targets $sk" ;;   # missing status counts as open, per the skill
  esac
done
[ "$n" -gt 0 ] && [ "$parsed" -eq 0 ] && notes+=("SCAN BROKEN: $n observation files, 0 headers parsed. Treat as a fault, not an empty log.")

# Step 3: review trigger.
last=$(tr -d '[:space:]' < "$W/last-review-date.txt" 2>/dev/null); : "${last:=never}"
cutoff=$(date -d '-7 days' +%F 2>/dev/null || date -v-7d +%F 2>/dev/null)
if [ "$open" -gt 0 ]; then
  if [ "$last" = never ]; then
    notes+=("Review never run and $open open observations: offer it in one line, then carry on with the user's task.")
  elif [ -n "$cutoff" ] && [ "$last" \< "$cutoff" ]; then
    notes+=("Last review $last (over 7 days) with $open open observations: offer it in one line, then carry on.")
  fi
fi

# Step 6: targets that no longer resolve, and staged work.
missing=""
for t in $(printf '%s\n' $targets | awk 'NF' | sort -u); do
  [ -d "$C/skills/$t" ] || missing="$missing $t"
done
[ -n "$missing" ] && notes+=("Observations target skills that are not installed:$missing.")
if [ -f "$C/skill-updates/PENDING.md" ]; then
  p=$(grep -c '^[-*] ' "$C/skill-updates/PENDING.md" 2>/dev/null); : "${p:=0}"
  [ "$p" -gt 0 ] && notes+=("$p staged skill updates awaiting review in skill-updates/PENDING.md.")
fi

by_skill=$(printf '%s\n' $open_targets | awk 'NF' | sort | uniq -c | awk '{printf "%s%s(%s)", (NR > 1 ? ", " : ""), $2, $1}')
msg="task-observer (hook-run start protocol): log at $L -- $open open, $parked parked, last review $last."
[ -n "$by_skill" ] && msg="$msg
- Open by skill: $by_skill. Before using one of these skills, read its open observations (grep -l the name in the log)."
for x in "${notes[@]+"${notes[@]}"}"; do msg="$msg
- $x"; done
msg="$msg
Watch the whole session for: a user correction that names a missing rule in an installed skill; a skill rule you broke; a reusable workflow no skill covers. When one happens, load the task-observer skill and write the observation in that turn. Flush pending observations at every push, publish or handed-over deliverable. At each task end, report one line: observations written (ids) or none and why."

esc=$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' | awk 'NR > 1 {printf "\\n"} {printf "%s", $0}')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
exit 0
