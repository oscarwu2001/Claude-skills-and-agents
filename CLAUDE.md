# Routing

Skills live in `~/.claude/skills/`, agents in `~/.claude/agents/`; their descriptions are already in context, so this file holds only what they can't say themselves.

- `/<name>` typed by the user → invoke that skill before anything else. Unsure which skill fits → read `/ask-matt` (the router; its **When two skills both look right** table settles competing pairs).
- **graphify answers, archify draws.** For a real codebase, query the graph first and author any diagram from it, never from guessed structure. `/archify` → local HTML file; `/system-map` → shareable Artifact.
- The agents are generic: each reads the project's `CLAUDE.md` `## Agent notes` for its commands, output folder and what counts as sensitive (template: `~/.claude/docs/agent-notes-template.md`).

# Work modes

Pick the row, not a search. Anything not listed → `/ask-matt`.

| Work | Start with | Hand off to |
|---|---|---|
| Research: a library, API, spec or "what's the right way to X" | `/research` (background `researcher`) | the file it writes → `/grill-with-docs` or `/to-spec` |
| Research: broad multi-source report (market, literature, comparison) | `anthropic-skills:deep-research` | — |
| Analysis: how this codebase works | graphify query if `graphify-out/` exists, else the `Explore` agent with a precise question | `/archify` or `/system-map` to show it |
| Analysis: numbers, experiments, sweeps | `runner` | — |
| Review: a branch or PR | `/code-review` — the local `~/.claude/skills/code-review` (standards + spec axes), not the built-in bug-hunting review | on data paths `silent-failure-hunter` first; visual work `ui-reviewer`; auth/input/secrets `/security-review` |
| Review: after I implement something | `reviewer` | fix, then re-run it; don't argue with a FAIL in prose |
| Documentation | `/documenting` | a picture → `/archify`; terms and decisions → `/domain-modeling` |
| Coding: specified work | `/implement` (drives `/tdd`) | `/code-review` before commit |
| Coding: something's broken, cause unknown | `/diagnosing-bugs` | `/tdd` once the cause is known |
| A workflow just worked and will recur | `/distill` — turn this run into a skill | the next real use of that skill is its first test |
| Step back: what would change the game (weekly, or "dream") | `dreamer` agent — ≤3 evidence-backed bets, memo outside the repo | the bet the user picks → the normal flow above |

# Finding things — no blind search

Every lookup starts from the most specific thing you already know, and escalates only when it misses.

1. **Known file or symbol** → `Grep` the exact name with `-n`, then `Read` with `offset`/`limit` around the hit. Not the whole file.
2. **`graphify-out/` exists** → for a question, read only `~/.claude/skills/graphify/references/query.md` and run `graphify query`. Load the full graphify skill only to build or update a graph.
3. **Location unknown** → one `Glob` or `Grep` on the most distinctive term, filtered by `type`/`glob`, in `files_with_matches` mode first; open the best one or two hits.
4. **Three misses, or more than five files to open** → stop. Delegate to `Explore` with a precise question and the paths already ruled out, or ask the user. Don't widen the pattern and try again.
5. **Facts outside the repo** → check the pinned version first (lockfile, `pyproject.toml`, `package.json`), then that version's official docs. More than one or two lookups → `/research`.

Never: read a file over ~300 lines whole to find one part; `find /` or recursive `ls` sweeps; re-read a file you already read and haven't changed; open `~/.claude/ecc-library` except through `/ecc`; paste a long log into the conversation.

# Token budget

- **Delegate execution, keep judgement.** Long output → `runner`; sweeps → `Explore`; reading → `researcher`. They return facts (failing test, assertion, numbers, citations), never diagnoses; planning, diagnosis and the fix stay here.
- **Load the part, not the skill.** When a skill points at a `references/` file for the current step, read that file alone. Big skills (graphify, task-observer, archify) are never loaded "just in case".
- **Logs to files.** Anything longer than a screen goes to a file; return the path and the lines that matter.
- **Context window.** `/clear` between unrelated tasks; `/compact` only at a phase boundary; near ~120k tokens mid-phase → `/handoff` and start fresh.

# Hook briefs

Hooks inject short briefs when they apply; follow them. The **project board** brief appears when other chats are active on this repo and carries its own rules. Record a decision other chats must follow with `bash ~/.claude/hooks/board.sh note "..."`; when the user gives this chat a role (owner, check, research…), record it with `bash ~/.claude/hooks/board.sh role <name>`.

**Task-observer:** the `SessionStart` brief beginning "task-observer (hook-run start protocol)" means its start protocol has run; load the skill only to log an observation, run a review, or act on a fault the brief reports. If that brief is missing in a main session, invoke the task-observer skill and run its Session Start Protocol before the first tool call. Subagents skip this. After each task, report one line: observations written (ids and titles) or none and why. The log lives in `skill-observations/` of the user-level `.claude` folder holding this file (Windows `%USERPROFILE%\.claude`, WSL `/mnt/c/Users/<name>/.claude`), never a path derived from the cwd.
