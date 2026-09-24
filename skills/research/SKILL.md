---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

Spin up a **background agent** to do the research, so you keep working while it reads.

Its job:

1. Investigate the question against **primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source.
3. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it somewhere sensible and say where.

<!-- LOCAL INTEGRATION — dispatch to the researcher subagent. -->
## This install

The background agent is the **`researcher`** subagent (`~/.claude/agents/researcher.md`): it carries the version pinning, source ladder, fetch budget, stop rules and file template. Spawn it with `run_in_background: true` and a brief of four lines:

- **Question:** one sentence.
- **Feeds:** the decision it settles.
- **Known:** what you already know or ruled out, with paths — so it doesn't re-search it.
- **Save to:** the notes folder, if you know it.

Several independent questions → one `researcher` per question, in parallel, never one agent with a list. Don't research in the main thread while it runs, and don't re-read the sources it cites; read its file.

If the `researcher` agent is missing, use `general-purpose` with the same brief plus the text of steps 1–3 above.

Not this skill: a broad multi-source report (market, literature, "compare the options in this field") → `anthropic-skills:deep-research`. How *this* codebase works → graphify or the `Explore` agent.
<!-- END LOCAL INTEGRATION -->
