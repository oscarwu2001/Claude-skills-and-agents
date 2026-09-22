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

Run `update-mattpocock-skills.sh` on one laptop, commit, push. Do not run it
on each laptop separately.
