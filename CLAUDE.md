# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

# ecc
- **ecc** (`~/.claude/skills/ecc/SKILL.md`) - router to the ECC catalogue kept unloaded at `~/.claude/ecc-library` (a git submodule). Trigger: `/ecc`, or a domain no installed skill covers.
Load one library item at a time; the router's table names what already has a local equivalent and must not be loaded twice. The `silent-failure-hunter` subagent is the one ECC agent installed for real.
