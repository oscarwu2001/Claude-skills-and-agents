# Skills provenance and local edits

Three independent sources live in this directory. Nothing here is a git checkout, so
this file is the only record of where each skill came from and what was changed locally.

| Source | Skills | Pinned at |
|---|---|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) | 21 engineering + productivity skills | mixed — see below |
| [tt-a1i/archify](https://github.com/tt-a1i/archify) (MIT) | `archify` | commit `9a50605`, v2.16.0-dev.0 — see [archify/UPSTREAM.md](archify/UPSTREAM.md) |
| `graphifyy` on PyPI | `graphify` | v0.9.33 (`.graphify_version`); SKILL.md self-installs the CLI via `uv tool` / `pip` |
| [rebelytics/one-skill-to-rule-them-all](https://github.com/rebelytics/one-skill-to-rule-them-all) (CC BY 4.0) | `task-observer` | commit `510caad` (v3.0.0, 2026-08-28), installed 2026-08-31. Bundle: SKILL.md + references/ + scripts/ (PNGs omitted). Its workspace is pinned at `~/.claude/skill-observations/` (activation block in `~/.claude/CLAUDE.md`) — that directory is user data, not part of the bundle; never delete it on a sync. |

## mattpocock/skills — sync state

Originally an unversioned snapshot dated **2026-07-27**, installed as editable copies
(`npx skills add`) rather than via the auto-updating plugin marketplace, so it does not
update itself. On **2026-08-28** three skills were selectively synced to upstream
`6654f6b` (2026-08-24). Line counts below are *real* content, excluding upstream's
em-dash→colon typography pass, which roughly doubles a naive diff.

| State | Skills |
|---|---|
| **Current with `6654f6b`** | `grilling`, `diagnosing-bugs`, `tdd` (synced, descriptions reapplied) · `implement`, `grill-me`, `grill-with-docs`, `handoff`, `research`, `resolving-merge-conflicts` (already matched) |
| **Behind, cosmetic or trivial** | `domain-modeling`, `teach` (3) · `to-spec` (4) · `prototype` (7) · `wayfinder` (28 lines, but no new sections — punctuation only) |
| **Behind, real content** | `ask-matt` (33, includes local edits) · `code-review` (13) · `setup-matt-pocock-skills` (13) · `improve-codebase-architecture` (12) · `to-tickets` (10) · `triage` (9) · `codebase-design` (8) |
| **Renamed upstream** | `writing-great-skills` → `productivity/writing-for-agents` |

**Present upstream, not installed here:** `wizard` (engineering), `wait-what`,
`to-questionnaire` (productivity). Upstream `deprecated/` is empty, so nothing
installed here has been retired.

### What the 2026-08-28 sync brought in

- **`grilling`** — rewritten upstream from a single paragraph into a **design tree** worked in **rounds**: the *frontier* is every decision whose prerequisites are settled, asked as numbered questions with recommended answers; sub-agents fetch facts so the user is never asked what could be looked up; done when the frontier is empty. Its `agents/openai.yaml` moved with it ("one question at a time" → "a round of questions at a time").
- **`diagnosing-bugs`** — adds a `## Redact` section (replace secrets with `<REDACTED>` before showing output) and restructures into `Phase 1–6` with completion criteria. Its `scripts/hitl-loop.template.sh` gained comments on `capture`.
- **`tdd`** — adds `## Seams: where tests go` (no test at an unconfirmed seam) and `## Anti-patterns`: implementation-coupled, tautological, horizontal slicing. Calls `codebase-design` for seam vocabulary.

## Local edits

Body edits are wrapped in `<!-- LOCAL INTEGRATION -->` / `<!-- END LOCAL INTEGRATION -->`.
Frontmatter `description:` rewrites **cannot** carry an HTML comment, so they are listed
here and nowhere else — a blind re-copy destroys them silently.
Find the marked ones with `grep -rn 'LOCAL INTEGRATION' ~/.claude/skills`.

### Body edits (marked)

| File | Edit |
|---|---|
| `ask-matt/SKILL.md` | `## Seeing the system` — adds graphify + archify to the router, which otherwise lists neither |
| `ask-matt/SKILL.md` | `## When two skills both look right` — boundary table resolving competing skill pairs |
| `graphify/SKILL.md` | `## For turning a graph answer into a diagram` — handoff to archify |
| `archify/SKILL.md` | `## Where this skill lives` — pins `$ARCHIFY`; upstream assumes the skill dir is the cwd |
| `archify/SKILL.md` | `## Working with the other installed skills` — graphify / code-review / spec handoffs |
| `improve-codebase-architecture/SKILL.md` | final bullet — hand the *chosen* candidate's before/after to `archify compare` |
| `ask-matt/SKILL.md` | `## Observing underneath` — routes task-observer as a background layer, never a destination |
| `ask-matt/SKILL.md` | boundary table — two rows added: task-observer vs writing-great-skills (process vs craft), observation log vs auto-memory (skill rule vs user/project fact) |
| `ask-matt/SKILL.md` | (2026-09-24) `## Standalone` — `/documenting` bullet; boundary table — three rows: research vs deep-research vs Explore, documenting vs domain-modeling, code-review vs the reviewer agent |
| `code-review/SKILL.md` | (2026-09-25) step 4 — the Standards sub-agent runs as the `reviewer` subagent (keeps its PASS/FAIL line and test run); Spec stays `general-purpose`; falls back to upstream when `reviewer` is missing |
| `research/SKILL.md` | (2026-09-24) `## This install` — dispatch to the `researcher` subagent with a four-line brief; one agent per question; boundary against deep-research and Explore |
| `task-observer/SKILL.md` | (2026-09-24) `## This install` — "Hook-run start protocol" bullet: steps 1–3 and 6 run in `~/.claude/hooks/observer-brief.sh`; load the skill only to log, review or act on a fault |
| `task-observer/SKILL.md` | `## This install` — pins the workspace path; requires UPSTREAM.md discipline (markers + record, same turn) for observer-driven edits to any provenance-tracked skill; pairs `references/skill-authoring.md` (process) with `writing-great-skills` (craft); draws the auto-memory boundary |

### Frontmatter `description:` rewrites (UNMARKED — reapply after any sync)

Rewritten so skills stop competing for the same prompt. Each states its boundary:

| Skill | Why |
|---|---|
| `graphify` | Upstream claimed "any question about a codebase" unconditionally, out-competing plain file reading. Greedy branch now fires only when `graphify-out/` exists. |
| `codebase-design` | Upstream claimed "find deepening opportunities" — `improve-codebase-architecture`'s job. That skill is user-invoked and cannot auto-fire, so the phrase reliably mis-routed the survey to the vocabulary skill. Removed, with a pointer. |
| `diagnosing-bugs` / `tdd` | Both claimed bug-fixing. Split on whether the cause is known. Reapplied after the 2026-08-28 sync. |
| `grilling` | Points at `grill-with-docs` inside a repo so the paper-trail wrapper isn't bypassed. Reapplied after the 2026-08-28 sync. |
| `archify` | Boundary against `graphify` (answer vs draw) and `dataviz` (topology vs numbers). |
| `task-observer` | (2026-09-24) Upstream's description orders a full-skill load before every session's first tool call — ~8k tokens a session. The `SessionStart` hook now runs those checks; the description keeps the logging triggers and falls back to the upstream behaviour when the hook's brief is absent. Upstream text: see the pinned commit. |

### Also changed

- (2026-09-24) **Not from any upstream:** `documenting/` (skill), `~/.claude/agents/researcher.md`, `~/.claude/hooks/observer-brief.sh`. A sync never touches them.
- `ask-matt` description: "a router over the skills in this repo" → "over every skill installed here".
- `agents/openai.yaml` added to `archify` and `graphify` so every skill carries interface metadata.
- `~/.claude/CLAUDE.md` rewritten from a graphify-only note into a skills index. Backup: `~/.claude/CLAUDE.md.bak`.
- `~/.claude/CLAUDE.md` (2026-08-31): task-observer index line + its activation block (Session Start Protocol trigger, post-task summary backstop, pinned workspace path). Upstream's template is in `task-observer/references/environments.md`; reapply the pinned path if ever re-copied.

## Updating safely

```bash
git clone --depth 1 https://github.com/mattpocock/skills.git /tmp/mp
diff -ru /tmp/mp/skills/engineering/<name> ~/.claude/skills/<name>
```

Per skill: copy upstream's directory over the local one, then reapply that skill's row
from the tables above. Diff against upstream afterwards — a correctly synced skill
differs on **line 3 only** (the description) if it has one, and nowhere else.
Refresh this file when done.
