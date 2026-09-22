# Installed skills

All live under `~/.claude/skills/`. When the user types `/<name>`, invoke that skill before doing anything else.

- **`/ask-matt`** — the router. Read it whenever you're unsure which skill fits: it maps the skills into flows (idea → spec → tickets → implement → review), and its **When two skills both look right** table settles the pairs that compete.
- **`/graphify`** — any input (code, docs, papers, images, video) → a persistent, queryable knowledge graph. Once `graphify-out/` exists in a project, treat architecture and "how does X work" questions as graphify queries first, before reading files.
- **`/archify`** — a system → a validated, self-contained interactive HTML diagram: architecture, workflow, sequence, dataflow, or lifecycle. Its files are relative to `~/.claude/skills/archify`, not the project — see its `## Where this skill lives`.
- **`/setup-matt-pocock-skills`** — run once per repo before the engineering flows; configures the issue tracker, triage labels, and doc layout they assume.
- **`/task-observer`** — background layer, never a destination: logs skill-improvement signals (corrections, uncovered needs, broken skill rules) to the observation log; a weekly review turns them into staged skill updates. Activation block below.
- **`/system-map`** — a codebase or system description → an interactive system map published as an Artifact. Prefers verified edges from `graphify-out/graph.json`. Use archify when the deliverable is a local HTML file, system-map when it is a shareable Artifact.
- **`/ecc`** — router to the ECC catalogue kept unloaded at `~/.claude/ecc-library` (a git submodule). Trigger: `/ecc`, or a domain no installed skill covers. Load one library item at a time; the router's table names what already has a local equivalent and must not be loaded twice.

**graphify answers, archify draws.** For a real codebase, run graphify first and author the archify spec from the graph — never from guessed structure.

# Subagents

All live under `~/.claude/agents/`.

- **`runner`** — long or noisy commands (test suites, builds, sweeps); returns a compact summary.
- **`reviewer`** — code-quality review after meaningful changes; PASS or FAIL.
- **`ui-reviewer`** — interface review (type, colour, layout, copy, accessibility) after visual work; Block or Approve.
- **`silent-failure-hunter`** — swallowed exceptions, hiding defaults and lost errors on data paths; run before the reviewer. The one ECC agent installed for real.

# Task-observer activation

Before the first tool call of any session — and before writing or
proposing a plan, not merely before executing one — invoke the
task-observer skill AND execute its Session Start Protocol (storage
check, frontmatter scan, review trigger). Loading the skill and running
the protocol are separate steps; a session that loads the file and stops
has activated nothing. Any turn that will involve a tool call counts; do
not classify the session as "too simple" from its opening message.

After completing each task, check the observation records written this
session and report a one-line summary (ids and titles, or "none logged
and why"). This is the activation backstop: it forces a look at the log,
so a session that silently skipped the protocol is discovered at the
first task boundary instead of never.

When loading any skill, check the observation log for OPEN observations
tagged to that skill. Apply their insights to the current work, even if
the skill file hasn't been updated yet.

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
