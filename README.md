# Claude skills and agents

Portable Claude Code configuration: `CLAUDE.md`, `settings.json`, the
user-level subagents in `agents/`, the skills in `skills/`, and the ECC
catalogue as a submodule in `ecc-library/` (unloaded; reached through the
`ecc` router skill).

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

Then add a `SessionStart` hook running `bash ~/.claude/wsl-link.sh` to WSL's own
`~/.claude/settings.json`, so new skills and projects are linked every session.
The script links agents, skills, `CLAUDE.md`, `ecc-library`, the observation log
and each Windows-drive project's auto-memory; its header says what stays
per-install and why. For graphify, put a wrapper at `~/.local/bin/graphify`
that runs `exec graphify.exe "$@"` rather than installing a second copy.

## Keep laptops in sync

```bash
git -C ~/.claude pull --ff-only && git -C ~/.claude submodule update --init
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
