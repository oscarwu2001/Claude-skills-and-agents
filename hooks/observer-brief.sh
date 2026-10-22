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
[ -n "${ROUTE_SHADOW_CHILD:-}" ] && { printf '{}\n'; exit 0; }   # route-shadow's classifier call

C="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)")/.." 2>/dev/null && pwd)"
# Could not locate our own .claude folder: inject nothing, so CLAUDE.md's fallback applies.
{ [ -n "$C" ] && [ -f "$C/hooks/observer-brief.sh" ]; } || { printf '{}\n'; exit 0; }
. "$C/hooks/firelog.sh" 2>/dev/null || firelog() { :; }   # shim log
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
# One awk over every file (2026-10-20, observation 0074): the old loop spawned
# four processes per file and took ~27 s at 154 files under Git Bash.
# CRLF and a UTF-8 BOM are normal for files hand-edited on Windows.
n=$(ls "$L"/*.md 2>/dev/null | wc -l | tr -d " "); parsed=0; open=0; parked=0; proposals=0; targets=""; open_targets=""
# A plugin-prefixed name whose bare name is a local skill is the same skill
# (observations 0046, 0160): count it once, under the bare name, per file.
# writing-for-agents is upstream's later name for the local writing-great-skills.
local_skills=$(ls "$C/skills" 2>/dev/null | tr '\n' ' ')
scan=$(awk -v loc="$local_skills" -v ren="writing-for-agents=writing-great-skills" '
  BEGIN { k = split(loc, a, " "); for (i = 1; i <= k; i++) have[a[i]] = 1
          k = split(ren, a, " "); for (i = 1; i <= k; i++) { split(a[i], kv, "="); rename[kv[1]] = kv[2] } }
  function canon(list,    k, i, t, b, out, seen) {
    k = split(list, w, " "); out = ""
    for (i = 1; i <= k; i++) {
      t = w[i]
      if (index(t, ":")) { b = substr(t, index(t, ":") + 1); if (b in rename) b = rename[b]
                           if (b in have) { alias[t] = 1; t = b } }
      if (!(t in seen)) { seen[t] = 1; out = out " " t }
    }
    return out
  }
  function flush() {
    if (!started) return
    if (!got) return                      # no frontmatter: not parsed, not counted
    parsed++; targets = targets " " sk
    if (st == "parked") parked++
    else if (st != "actioned" && st != "declined" && st != "superseded") {
      open++; open_targets = open_targets " " canon(sk)   # missing status counts as open, per the skill
      t = sk; gsub(/[[:space:]]/, "", t); if (t == "" && ps) proposals++
    }
  }
  FNR == 1 { flush(); started = 1; fm = 0; got = 0; st = ""; have_st = 0; sk = ""; ps = 0; blk = ""; sub(/^\xef\xbb\xbf/, "") }
  { sub(/\r$/, "") }
  FNR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
  !fm { nextfile }
  /^---[[:space:]]*$/ { fm = 0; nextfile }
  { got = 1 }
  /^status:/ { if (!have_st) { s = $0; sub(/^status:/, "", s); sub(/#.*/, "", s); gsub(/[[:space:]"\047]/, "", s); st = s; have_st = 1 } blk = ""; next }
  # skill: [a, b] | skill: a | skill:\n  - a
  /^skill:/ { s = $0; sub(/^skill:[[:space:]]*/, "", s); sub(/#.*/, "", s); gsub(/[][,"\047]/, " ", s); sk = sk " " s; blk = "skill"; next }
  /^proposes_skill:/ { s = $0; sub(/^proposes_skill:/, "", s); sub(/#.*/, "", s); gsub(/[][,"\047[:space:]]/, "", s); if (s != "") ps = 1; blk = "ps"; next }
  /^[[:space:]]*-/ { if (blk == "skill") { s = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", s); sub(/#.*/, "", s); gsub(/["\047]/, "", s); sk = sk " " s } else if (blk == "ps") ps = 1; next }
  { blk = "" }
  END { flush(); for (t in alias) aliases = aliases " " t
        printf "%d %d %d %d\n%s\n%s\n%s\n", parsed, open, parked, proposals, targets, open_targets, aliases }
' "$L"/*.md 2>/dev/null)
aliases=""
if [ -n "$scan" ]; then
  read -r parsed open parked proposals <<EOF
$(printf '%s\n' "$scan" | sed -n 1p)
EOF
  targets=$(printf '%s\n' "$scan" | sed -n 2p); open_targets=$(printf '%s\n' "$scan" | sed -n 3p)
  aliases=$(printf '%s\n' "$scan" | sed -n 4p)
fi
set -f   # skill names like "*" must not expand from here on
[ "$n" -gt 0 ] && [ "$parsed" -eq 0 ] && notes+=("SCAN BROKEN: $n observation files, 0 headers parsed. Treat as a fault, not an empty log.")

# Step 3: review trigger.
last=$( { tr -d '[:space:]' < "$W/last-review-date.txt"; } 2>/dev/null); : "${last:=never}"
case "$last" in
  never|[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) notes+=("last-review-date.txt holds '$last', not a date or 'never': treat the review as due."); last=never ;;
esac
cutoff=$(date -d '-7 days' +%F 2>/dev/null || date -v-7d +%F 2>/dev/null)
if [ "$open" -gt 0 ]; then
  if [ "$last" = never ]; then
    notes+=("Review never run and $open open observations: offer it in one line, then carry on with the user's task.")
  elif [ -n "$cutoff" ] && [ "$last" \< "$cutoff" ]; then
    notes+=("Last review $last (over 7 days) with $open open observations: offer it in one line, then carry on.")
  fi
fi

# Step 6: targets that no longer resolve, and staged work.
[ -n "$aliases" ] && notes+=("Some observations name local skills by a plugin alias (counted under the bare name):$aliases. Write the bare installed name.")
missing=""
pdir="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/skills"
for t in $(printf '%s\n' $targets | awk 'NF' | sort -u); do
  case "$t" in *:*) continue ;; esac   # plugin skills live elsewhere
  [ -d "$C/skills/$t" ] || [ -f "$C/agents/$t.md" ] && continue
  [ -d "$pdir/$t" ] || missing="$missing $t"
done
[ -n "$missing" ] && notes+=("Observation targets not installed globally:$missing. Project skills live in each project's .claude/skills (the observation's session_context names the project); a name found in no project is a deleted skill.")
if [ -f "$C/skill-updates/PENDING.md" ]; then
  p=$(grep -c '^[-*] ' "$C/skill-updates/PENDING.md" 2>/dev/null); : "${p:=0}"
  [ "$p" -gt 0 ] && notes+=("$p staged skill updates awaiting review in skill-updates/PENDING.md.")
fi
# Staging anywhere else is never announced, so never installed (observation 0165).
[ -n "$(ls -A "$W/skill-updates" 2>/dev/null)" ] && notes+=("Staged updates found under skill-observations/skill-updates/: nothing announces them there. Reviews stage to ~/.claude/skill-updates/ with a PENDING.md entry.")

by_skill=$(printf '%s\n' $open_targets | awk 'NF' | sort | uniq -c | awk '{printf "%s%s(%s)", (NR > 1 ? ", " : ""), $2, $1}')
msg="task-observer (hook-run start protocol): log at $L -- $n files, $open open, $parked parked, last review $last."
[ "$proposals" -gt 0 ] && msg="$msg
- $proposals open observations propose new skills (proposes_skill, no skill target)."
[ -n "$by_skill" ] && msg="$msg
- Open by skill: $by_skill. Before using one of these skills, read its open observations: grep -lE '^skill:.*\bNAME\b' in the log, then keep those whose status is open. Grep the log again mid-session when a defect class recurs."
for x in "${notes[@]+"${notes[@]}"}"; do msg="$msg
- $x"; done
msg="$msg
Watch the whole session for: a user correction that names a missing rule in an installed skill; a skill rule you broke; a reusable workflow no skill covers. When one happens, load the task-observer skill and write the observation in that turn. Flush pending observations at every push, publish or handed-over deliverable. At each task end, report one line: observations written (ids) or none and why."

firelog observer-brief brief "open=$open notes=${#notes[@]}"
esc=$(printf '%s' "$msg" | tr -d '\000-\010\013-\037' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' | awk 'NR > 1 {printf "\\n"} {printf "%s", $0}')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
exit 0
