# Claude skills and agents

Portable Claude Code configuration: `CLAUDE.md`, `settings.json`, the
user-level subagents in `agents/`, the skills in `skills/`, the hooks in
`hooks/`, and the ECC
catalogue as a submodule in `ecc-library/` (unloaded; reached through the
`ecc` router skill).

Commands below are for Git Bash or WSL, where `~` is your home folder. In
Windows Command Prompt write `%USERPROFILE%` instead of `~` (PowerShell: `$HOME`),
and backslashes: `git -C "%USERPROFILE%\.claude" pull --ff-only`.

Everything else that Claude Code keeps in `~/.claude` (sessions, transcripts,
memory, caches, local settings) is ignored by the allowlist in `.gitignore`
and never leaves the machine.

## New laptop

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/oscarwu2001/Claude-skills-and-agents.git ~/.claude
```

If `~/.claude` already exists, clone elsewhere, then move `.git`, `.gitignore`,
`.gitmodules` and the tracked files in, and run `git submodule update --init`.

## WSL on the same laptop

The Windows checkout is the only configuration. WSL's Claude Code reads
`/home/<name>/.claude` instead, so link it across once:

```bash
bash /mnt/c/Users/<name>/.claude/wsl-link.sh
```

Then add one `SessionStart` hook to WSL's own `~/.claude/settings.json` with
the command `bash ~/.claude/wsl-link.sh; bash ~/.claude/hooks/observer-brief.sh`
— one command, because separate hooks run in parallel and the brief needs the
links. The first links new skills and projects every session; the second is the
task-observer brief (the Windows entry is in the tracked `settings.json`). The script links agents, skills, hooks, `CLAUDE.md`,
`ecc-library`, the observation log
and each Windows-drive project's auto-memory; its header says what stays
per-install and why. For graphify, put a wrapper at `~/.local/bin/graphify`
that runs `exec graphify.exe "$@"` rather than installing a second copy.

## Context cap

`hooks/context-cap.sh` stops a main session from growing until every turn
re-reads hundreds of thousands of tokens. On each prompt it reads the last
turn's usage from the session transcript. Past 200K tokens it asks for a
handoff at the next stopping point, once per 50K step. Past 400K it asks on
every prompt, before any other work, unless you have said to carry on.

The handoff goes to `~/.claude/handoffs/<project>/<date>-<session>.md`, which
is never tracked. When you `/clear` or start a new session in the same
project, the hook points it at the newest handoff that is under 14 days old.
The session renames that file to `*.done.md` once it has picked it up.

Set `CONTEXT_CAP_SOFT` or `CONTEXT_CAP_HARD` (in tokens) to move the lines,
and turn it off with `mkdir -p ~/.claude/context-cap && touch ~/.claude/context-cap/off`.
In WSL, add its `SessionStart` (`startup|clear`) and `UserPromptSubmit` entries
from `settings.json` to WSL's own settings.

The reason: from 23 September to 20 October, 90% of main-session turns ran
above 120K context. One session averaged 494K over 2,229 turns. Re-reading the
cached context was 76% of main-session cost, and the old "hand off near 120K"
rule in `CLAUDE.md` never fired on its own.

## Verdict ledger

`hooks/verdict-ledger.sh` makes review verdicts countable. The three review
agents (`reviewer`, `ui-reviewer`, `silent-failure-hunter`) end every report
with one line:

```
VERDICT: FAIL findings=3 blocking=1 sha=3f2a9c1
```

`PASS` means no blocking finding, `FAIL` at least one, and `BLOCKED` that the
review could not be finished. `findings` counts everything reported,
`blocking` counts what must be fixed, and `sha` is the commit reviewed (with
`+` if uncommitted changes were reviewed too, `none` outside git).

When one of those agents stops, the hook reads that line and adds a row to
`~/.claude/verdict-ledger/verdicts.tsv`, which is never tracked. If the line
is missing or does not add up (a `PASS` with blocking findings, say), the hook
sends the agent back once to add it. If it is still missing the second time,
the agent is let go and the row says `MISSING`. `UNREAD` means the hook could
not read the agent's final message at all.

When the main session acts on a `FAIL`, by fixing it or by deciding it was
wrong, it records the outcome:

```bash
bash ~/.claude/hooks/verdict-ledger.sh list
bash ~/.claude/hooks/verdict-ledger.sh outcome 12 real      # or false-alarm
```

`real` means at least one blocking finding was a real bug. After a few weeks
the ledger shows how often each reviewer's `FAIL`s were real. That is the
number to look at before cutting any reviewer.

Turn it off with `mkdir -p ~/.claude/verdict-ledger && touch ~/.claude/verdict-ledger/off`.
In WSL, add the `SubagentStop` entry from `settings.json` to WSL's own settings.

The reason: 63 of 133 review runs from 23 September to 20 October put their
verdict where no script could find it, so the Agents Home report counted none.
Research on 22 October found that stacking reviewers on one model adds little,
because their mistakes overlap, while checks that actually run the code add
real signal. The ledger measures this for our own pipeline before anything is
cut.

## Helper reminders (Agents Home)

`hooks/agents-home-router.sh` comes with the Agents Home app. When a prompt
fits one of the agents (by keyword), it adds a one-line reminder to use that
agent. It names the house agents, `reviewer` and `runner`, and stays silent
on background task notifications and helper hand-backs. The app also installed `code-reviewer` and
`test-runner`, which duplicated `reviewer` and `runner`. They are retired to
`agents-retired/`, which is not tracked. If an app update reinstalls them or
rewrites the hook, move them out and re-apply the change.

## Shadow router (off)

`hooks/route-shadow.sh` was a shadow-mode router. On every prompt, haiku
classified the request into a work mode with a confidence, and the skill or
agent the main model actually used was logged beside it. It is off since
20 October 2026 (`route-shadow/off`). Over 14 days it classified 976 prompts
for $19.31. At confidence 0.85 or higher it agreed with the route actually
taken only 21% of the time, because most routing happens when a helper
finishes, not at the user's prompt. So a prompt-level router would not help.
The log stays in `route-shadow/log.jsonl`, which is never tracked. To rerun
the experiment, delete `route-shadow/off`, then:

```bash
python3 ~/.claude/hooks/route-shadow-report.py      # `python` on Windows
```

## Shim log

Every hook that adds text to a conversation logs one line when it fires, so a
rule that has stopped firing can be found and removed. This is the "track shims
centrally" idea from Cursor's talk "Is the harness dead?". The hooks source
`hooks/firelog.sh`, which appends `timestamp, hook, event, detail` to
`~/.claude/shim-log/fires.tsv`. That file is never tracked. The detail is a
size, a count or an agent name, never prompt text. Timed in Git Bash, the
added cost is within noise: a hook run takes about 400 ms either way.

| Hook | Events logged |
|---|---|
| `context-cap.sh` | `soft` and `hard` (context size), `pickup` (handoff file name) |
| `agents-home-router.sh` | one row per tip shown, named by agent (`reviewer`, `runner`, ...) |
| `board.sh` | `start` (counts), `same-folder`, `updates` (count), `edit-warning` |
| `observer-brief.sh` | `brief` (open observations, notes) |
| `verdict-ledger.sh` | `block` (agent sent back for its verdict line, by agent name) |

Once a month, run:

```bash
bash ~/.claude/hooks/shim-report.sh
```

It lists each hook and event with its last fire and its count over 30 days.
Once the log is 30 days old, it also flags anything silent for that long. A
silent rule is a candidate to delete: either the problem it guarded against no
longer happens, or nothing triggers it any more.

To wire another hook, add `. "$C/hooks/firelog.sh" 2>/dev/null || firelog() { :; }`
near its top, where `$C` is the `.claude` folder, and `firelog <hook> <event> [detail]`
where it injects or blocks; use the script's file name as `<hook>`.
`agents-home-router.sh` belongs to the Agents Home app, so re-add its two lines
if an app update rewrites it.

## Parallel chats on one repo

`hooks/board.sh` keeps a **project board** per git repo, in `.git/claude-board/`
(shared by every worktree, never committed). Every chat on the repo sees, via
hooks, what the other chats edited, committed and decided since its last turn,
and gets a warning before editing a file another chat just changed. Chats add
decisions with `board.sh note "..."`; read the whole board yourself with:

```bash
bash ~/.claude/hooks/board.sh show
```

(From Command Prompt: `bash "%USERPROFILE%\.claude\hooks\board.sh" show`, run
inside the repo.)

Give chats roles so they address each other by job, not by id: tell a chat
"you are the owner" (it runs `board.sh role owner`), another "you are the
checker". Hand-offs between them carry a task packet (outcome, files,
acceptance, proof, limits), and the checker reviews the exact commit the
owner names. Naming the session the same (`claude --name owner`) makes it
easy to find with `/list-agents`.

For parallel *code* changes, start each chat in its own worktree so edits
can't collide, and let the board carry the knowledge between them:

```bash
claude -w api-rename      # chat 1
claude -w docs-refresh    # chat 2
```

In WSL, add the `board.sh` entries from `settings.json` (SessionStart,
UserPromptSubmit, PreToolUse, PostToolUse, SessionEnd) to WSL's own settings.

## Dreamer

The `dreamer` agent steps back once a week (or when you say "dream") and
returns at most three evidence-backed bets on what would change the game, each
with a cheap experiment and a kill criterion. It reads the project's existing
goal and plan docs rather than adding any; its memos go to
`~/.claude/dreams/<repo>/`, never into the project.

## Per-project agent notes

The agents are generic. Give each project an `## Agent notes` section in its
`CLAUDE.md` naming its commands, output directory and sensitive data; the
template and the spine/C-arm projects' filled-in block are in
`docs/agent-notes-template.md`.

## Keep laptops in sync

```bash
git -C ~/.claude pull --ff-only && git -C ~/.claude submodule update --init
```

Windows Command Prompt:

```cmd
git -C "%USERPROFILE%\.claude" pull --ff-only && git -C "%USERPROFILE%\.claude" submodule update --init
```

## Update ECC

```bash
git -C ~/.claude submodule update --remote --depth 1 ecc-library
git -C ~/.claude commit -am "Bump ecc-library"
git -C ~/.claude push
```

After a bump, re-check the "do not load" table in `skills/ecc/SKILL.md`: a new
ECC item may duplicate a local skill or agent.

## Change log

**2026-10-22.** These changes follow research on Cursor's talk "Is the
harness dead?" and the papers it cites. Instructions on how to code no longer
make a current model better at coding, but they still cost tokens on every
turn.

- **Added the shim log** (see [Shim log](#shim-log)): `hooks/firelog.sh`,
  `hooks/shim-report.sh`, and in each hook that injects text, one line to load
  the helper plus one call per event.
- **Trimmed `CLAUDE.md`** from 6.1 KB to 5.0 KB. The "Finding things" lookup
  steps went, because the model already searches that way. The graphify
  `query.md` shortcut and the ecc-library rule moved under "Load the part, not
  the skill". "Short helpers" no longer says a helper's cost grows with the
  square of its length: builder cost per minute stays flat, and the cost that
  grows is a long main session.
- **Hid `prototype` and `ecc` from the model** with `disable-model-invocation:
  true`. `/prototype` and `/ecc` still work. Neither was used from 23 September
  to 20 October, and `CLAUDE.md` does not point at them. On the rest of the
  report's "installed, not used" list, 14 skills were already hidden, 5 are
  named in `CLAUDE.md`, `tdd` calls `codebase-design`, `research` was used on
  22 October, and 4 skills are new.
- **Measured:** a fresh session's first call read about 44,700 tokens. In
  side-by-side runs, the `CLAUDE.md` cut saves about 380 tokens and the two
  hidden skills about 240: 620 in all, or 1.4%. No study has tested personal
  `CLAUDE.md` files, so this is an experiment. If review results or session
  cost get worse over the next two weeks, revert it.

**2026-10-22, verdict ledger.** Step 1 of the review plan from the same
research: measure what review is worth before cutting any reviewer.

- **Added `hooks/verdict-ledger.sh`** (see [Verdict ledger](#verdict-ledger)),
  wired to `SubagentStop` in `settings.json` for the three review agents. It
  writes to the shim log each time it sends an agent back.
- **`agents/reviewer.md`, `ui-reviewer.md` and `silent-failure-hunter.md`**
  now end with the same `VERDICT:` line. It replaces reviewer's bare
  `PASS`/`FAIL` first line and ui-reviewer's closing Block or Approve (Block
  is now `FAIL`, Approve is `PASS`). silent-failure-hunter counts its high
  and medium findings as blocking. `/code-review` keeps the closing line
  instead of the opening one.
- **`agents/builder.md`**: the handoff gained an `Evidence:` line. It lists
  the checks the builder ran but did not write in that phase (existing tests,
  the project's gate, running the app, before/after output), with results and
  log paths, or says `none independent:` and why. Tests the builder wrote
  itself stay under `Tests:`, because in the research such tests did not
  change outcomes.
- **`CLAUDE.md`**: one line telling the main session to record the outcome
  each time it acts on a `FAIL`.

**2026-10-20.** These changes come from the Agents Home report for 23 September
to 20 October (396 helper runs) and from the session transcripts.

- **Added `hooks/context-cap.sh`** (see [Context cap](#context-cap)), wired to
  `UserPromptSubmit` and `SessionStart` in `settings.json`. The context-window
  line in `CLAUDE.md` now points at it instead of "near ~120k → /handoff".
- **`agents/runner.md`** gained a `## Windows` section: Git Bash path forms,
  PowerShell called through `powershell.exe -Command`, script files when a
  command needs nested quotes, no `sleep` polling, and Read size limits.
  runner and test-runner had the highest tool-error rates (18% and 12%),
  mostly PowerShell syntax and backslash paths sent to Git Bash. It also took
  over test-runner's triggers and the README fallback for finding the test
  command.
- **`agents/reviewer.md`** took code-reviewer's output contract. The first line
  is the bare `PASS` or `FAIL`. Each finding is `file:line`, what goes wrong and
  when, and the smallest fix, with no style opinions that no rule asks for.
  It also took the rule against repeating patient identifiers. Its
  description keeps branch and PR reviews with `/code-review`. 63 of 133
  review runs had put their verdict somewhere other than the first line, so
  the report could not count verdicts.
- **Retired `code-reviewer` and `test-runner`** to `agents-retired/`, and
  pointed `hooks/agents-home-router.sh` at `reviewer` and `runner`. The hook
  also now ignores background task notifications and helper hand-backs, which it used to answer
  with suggestions.
- **Turned off the shadow router** (see [Shadow router](#shadow-router-off)).

## Update Matt Pocock's skills

They are installed flat, one folder per skill under `skills/`, and carry local
edits marked `<!-- LOCAL INTEGRATION -->`. `skills/UPSTREAM.md` records the
upstream commit each one is synced to and every local edit. Sync on one laptop,
update that file, commit, push. Do not sync on each laptop separately.
