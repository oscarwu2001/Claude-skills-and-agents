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

## Shadow router

`hooks/route-shadow.sh` is a shadow-mode router in the style of a System One
model: on every prompt, haiku classifies the request into a work mode with a
confidence (in the background, about $0.004 each), and the skill or agent the
main model actually used is logged beside it. It injects and blocks nothing.
The log (`route-shadow/log.jsonl`, never tracked) holds ids, times, modes and
route names, never prompt text. After a week or two:

```bash
python3 ~/.claude/hooks/route-shadow-report.py      # `python` on Windows
```

High agreement at high confidence means a confidence-gated router could safely
suggest routes; confident disagreements show where routing goes wrong. Turn it
off with `touch ~/.claude/route-shadow/off`. In WSL, add its `UserPromptSubmit`
and `PreToolUse` entries from `settings.json` to WSL's own settings.

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

For parallel *code* changes, start each chat in its own worktree so edits
can't collide, and let the board carry the knowledge between them:

```bash
claude -w api-rename      # chat 1
claude -w docs-refresh    # chat 2
```

In WSL, add the `board.sh` entries from `settings.json` (SessionStart,
UserPromptSubmit, PreToolUse, PostToolUse, SessionEnd) to WSL's own settings.

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

## Update Matt Pocock's skills

They are installed flat, one folder per skill under `skills/`, and carry local
edits marked `<!-- LOCAL INTEGRATION -->`. `skills/UPSTREAM.md` records the
upstream commit each one is synced to and every local edit. Sync on one laptop,
update that file, commit, push. Do not sync on each laptop separately.
