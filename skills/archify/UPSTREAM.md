# Upstream provenance

| | |
|---|---|
| Source | https://github.com/tt-a1i/archify |
| Vendored path | the repo's `archify/` subdirectory (the skill payload) |
| Commit | `9a5060566c832832fb843e457e58c8ee6bac82fd` |
| Commit date | 2026-08-27 |
| Version | `2.16.0-dev.0` (see `.archify_version`) |
| Installed | 2026-08-28 |
| License | MIT (see `LICENSE`) |

Installed by hand rather than via `npx skills add tt-a1i/archify -g`, so that the
local patches below are recorded and re-appliable.

## Local patches

Two edits to `SKILL.md`, both confined to marked blocks. Nothing else is modified.

1. **`description:` in the frontmatter** — retitled to lead with the verb, collapsed
   to one trigger per branch, and given a closing clause that hands codebase
   *questions* to `graphify` so the two skills stop competing for the same prompt.
2. **A `LOCAL INTEGRATION` block** between the intro and `## Fast authoring path`,
   delimited by `<!-- LOCAL INTEGRATION -->` / `<!-- END LOCAL INTEGRATION -->`.
   It pins `$ARCHIFY` to the absolute skill directory (upstream assumes the skill
   dir is the working directory; under Claude Code it is the user's project), and
   names the graphify / code-review handoffs.

## Updating

```bash
git clone --depth 1 https://github.com/tt-a1i/archify.git /tmp/archify-src
diff -u /tmp/archify-src/archify/SKILL.md ~/.claude/skills/archify/SKILL.md   # should show only the two patches
cp -r /tmp/archify-src/archify/. ~/.claude/skills/archify/
```

Then re-apply both patches, refresh the table above, and re-run
`node "$HOME/.claude/skills/archify/bin/archify.mjs" doctor`.
