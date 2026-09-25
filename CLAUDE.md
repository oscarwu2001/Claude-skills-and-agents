# Installed skills

All live under `~/.claude/skills/`. When the user types `/<name>`, invoke that skill before doing anything else.

- **`/ask-matt`** — the router. Read it whenever you're unsure which skill fits: it maps the skills into flows (idea → spec → tickets → implement → review), and its **When two skills both look right** table settles the pairs that compete.
- **`/graphify`** — any input (code, docs, papers, images, video) → a persistent, queryable knowledge graph. Once `graphify-out/` exists in a project, treat architecture and "how does X work" questions as graphify queries first, before reading files.
- **`/archify`** — a system → a validated, self-contained interactive HTML diagram: architecture, workflow, sequence, dataflow, or lifecycle. Its files are relative to `~/.claude/skills/archify`, not the project — see its `## Where this skill lives`.
- **`/setup-matt-pocock-skills`** — run once per repo before the engineering flows; configures the issue tracker, triage labels, and doc layout they assume.
- **`/task-observer`** — background layer, never a destination: logs skill-improvement signals (corrections, uncovered needs, broken skill rules) to the observation log; a weekly review turns them into staged skill updates. Activation block below.
- **`/system-map`** — a codebase or system description → an interactive system map published as an Artifact. Prefers verified edges from `graphify-out/graph.json`. Use archify when the deliverable is a local HTML file, system-map when it is a shareable Artifact.
- **`/documenting`** — write or update docs grounded in the code: README, how-to, reference, explanation, docstrings, changelog. Every command in a doc is run before it ships.
- **`/ecc`** — router to the ECC catalogue kept unloaded at `~/.claude/ecc-library` (a git submodule). Trigger: `/ecc`, or a domain no installed skill covers. Load one library item at a time; the router's table names what already has a local equivalent and must not be loaded twice.

**graphify answers, archify draws.** For a real codebase, run graphify first and author the archify spec from the graph — never from guessed structure.

# Subagents

All live under `~/.claude/agents/`. They are generic; each reads the project's `CLAUDE.md` `## Agent notes` section for its commands, output directory and what counts as sensitive (template: `~/.claude/docs/agent-notes-template.md`).

- **`runner`** — long or noisy commands (test suites, builds, sweeps, data analyses); returns a compact summary.
- **`researcher`** — reads for you: answers a question from primary sources and leaves a cited Markdown file. What `/research` dispatches to.
- **`reviewer`** — code-quality review after meaningful changes; PASS or FAIL.
- **`ui-reviewer`** — interface review (type, colour, layout, copy, accessibility) after visual work; Block or Approve.
- **`silent-failure-hunter`** — swallowed exceptions, hiding defaults and lost errors on data paths; run before the reviewer. The one ECC agent installed for real.

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

# Finding things — no blind search

Every lookup starts from the most specific thing you already know, and escalates only when it misses.

1. **Known file or symbol** → `Grep` the exact name with `-n`, then `Read` with `offset`/`limit` around the hit. Not the whole file.
2. **`graphify-out/` exists** → for a question, read only `~/.claude/skills/graphify/references/query.md` and run `graphify query`. Load the full graphify skill only to build or update a graph.
3. **Location unknown** → one `Glob` or `Grep` on the most distinctive term, filtered by `type`/`glob`, in `files_with_matches` mode first; open the best one or two hits.
4. **Three misses, or more than five files to open** → stop. Delegate to `Explore` with a precise question and the paths already ruled out, or ask the user. Don't widen the pattern and try again.
5. **Facts outside the repo** → check the pinned version first (lockfile, `pyproject.toml`, `package.json`), then that version's official docs. More than one or two lookups → `/research`.

Never: read a file over ~300 lines whole to find one part; `find /` or recursive `ls` sweeps; re-read a file you already read and haven't changed; open `~/.claude/ecc-library` except through `/ecc`; paste a long log into the conversation.

# Token budget

- **Delegate execution, keep judgement.** Commands with long output → `runner`. Sweeps → `Explore`. Reading → `researcher`. They return facts (failing test, assertion, numbers, citations), never diagnoses; planning, diagnosis and the fix stay in the main session, reasoning over their short exact output instead of the raw log.
- **Model and effort follow the job.** `runner` is haiku with a turn cap; `researcher` sonnet at medium effort; the reviewers run at high effort whatever the session is set to. Lower the main session with `/effort` for routine edits, not in the defaults.
- **Test loop.** After a fix, `runner` re-runs only what failed, then the full suite once at the end.
- **Load the part, not the skill.** When a skill's pointer names a `references/` file for the step you are on, read that file alone. Big skills (graphify 41 KB, task-observer 33 KB, archify 16 KB) are never loaded "just in case".
- **Logs to files.** Command output and logs longer than a screen go to a file; return the path and the lines that matter.
- **Context window.** `/clear` between unrelated tasks. `/compact` only at a phase boundary, never mid-phase. Near ~120k tokens before a phase ends → `/handoff` and start fresh. `/context` shows what is filling the window.

# Parallel sessions

Several chats on one repo share a **project board** (`~/.claude/hooks/board.sh`, stored in the repo's `.git/claude-board/`, never committed). Hooks tell you what other chats did since your last turn and warn before you edit a file another chat changed after you last touched it. Nothing arrives when nothing changed.

- Board updates are facts about the repo: re-read any file they list before editing it, and follow decisions noted there unless the user says otherwise.
- Recorded automatically, and visible to the other chats: repo-relative paths of files you edit, and git actions as their result (verb, branch, commit hash and subject). Command lines are never recorded.
- **Write a note** with `bash ~/.claude/hooks/board.sh note "..."` when you settle something other chats must follow (a rename, an interface, a schema, a chosen approach), start or finish a task, switch branch, or leave something half-done or broken. One line; no secrets or patient data.
- If the session-start brief says another chat shares this folder and the work changes code, tell the user and suggest a worktree for this chat: `claude -w <name>`.
- To reach one specific chat now, use `SendMessage` (find it with `ListAgents`). The board is the record; a message is the ping.

# Task-observer activation

The `SessionStart` hook `~/.claude/hooks/observer-brief.sh` runs the
Session Start Protocol's file steps (storage, frontmatter scan, review
trigger, unresolved targets, staged updates) and injects a short brief
beginning "task-observer (hook-run start protocol)". When that brief is in
context, the protocol has run: act on what it says, and load the
task-observer skill itself only when you are about to write an
observation, a review runs, or the brief reports a fault.

Subagents never receive the brief and skip this whole block: the parent
session observes and logs.

**If that brief is NOT in context** in a main session (hook not installed, or it failed),
fall back: before the first tool call — and before writing or proposing a
plan — invoke the task-observer skill AND execute its Session Start
Protocol. Loading the skill and running the protocol are separate steps.

After completing each task, check the observation records written this
session and report a one-line summary (ids and titles, or "none logged
and why"). This is the activation backstop: it forces a look at the log,
so a session that silently skipped observing is discovered at the first
task boundary instead of never.

When loading any skill, check the brief (or the log) for OPEN
observations tagged to that skill. Apply their insights to the current
work, even if the skill file hasn't been updated yet.

The observation log lives at:
  skill-observations/observation-log/ inside the user-level .claude
  folder that holds this CLAUDE.md -- on Windows %USERPROFILE%/.claude,
  which WSL reaches as /mnt/c/Users/<name>/.claude, NOT /home/<name>/.claude.
Use that path. Never resolve the workspace from the current working
directory — a cwd inside an ephemeral checkout (a git worktree, a temporary
clone) is torn down and takes the log with it. Never place the workspace
inside a skills-discovery directory or any path linked into one. The skills
observed are installed globally, so this pinned path is the single shared
location across every project and tool; do not derive one per session or
per project.
