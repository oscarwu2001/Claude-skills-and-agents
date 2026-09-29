---
name: distill
description: Turn a workflow that just succeeded in this conversation into a reusable skill, with every mistake made along the way written in as a rule and the run saved as a test case.
disable-model-invocation: true
argument-hint: "Name or one line on the workflow to capture (optional)"
---

A skill **distilled** from a real run: every step is one that actually happened, every rule is a mistake that actually happened. Nothing is added from imagination; a step you didn't take this session doesn't go in.

## 1. Confirm there is a run worth distilling

The run must have **succeeded** in this conversation: the user got the result they wanted. If the outcome is unclear, ask "did this come out right?" and stop until it is confirmed. A workflow that never worked end to end is a plan, not a skill.

**Done when:** the user has confirmed the outcome, in this conversation.

## 2. Reconstruct the run

From this conversation, write down in working notes:

- **Goal:** one sentence, in the user's words.
- **Inputs:** what the workflow starts from (a file type, a question, a repo state).
- **Steps as actually taken, in order:** tools, commands, skills and agents used, and the decision made at each fork.
- **Every correction:** each time the user corrected you, a step failed, or you backtracked. What went wrong, what fixed it.
- **Success looked like:** the checkable properties of the final result.

**Done when:** every correction in the conversation is on the list. Scroll back for them; a missed correction is a rule the skill won't have.

## 3. Check what already exists

Search installed skill names and descriptions (`~/.claude/skills/*/SKILL.md` frontmatter, and the project's `.claude/skills/`) and the task-observer log for a `proposes_skill` naming this workflow. If a skill already covers it, **update that skill** with the new steps and rules instead of creating a second one.

**Done when:** you can name the file you will create or edit, and why.

## 4. Write the skill

Load `writing-great-skills` first; it governs the writing. Then:

- **Name:** the workflow's leading word, kebab-case.
- **Invocation:** user-invoked (`disable-model-invocation: true`) unless the agent must trigger it unprompted or another skill must reach it. User-invoked costs no context until it is typed.
- **Steps** from step 2, generalised: real paths, IDs and names from this run become placeholders or a note on how to find them. Each step ends on a checkable completion criterion.
- **Each correction becomes a rule** under the step where it bit, phrased as the behaviour to do ("check X before Y"), with one clause on why.
- Reference material only some runs need goes in a `references/` file behind a pointer. Aim for under 150 lines in `SKILL.md`.

**Done when:** every correction from step 2 appears as a rule, and no step appears that the run did not take.

## 5. Save the run as a test case

Write `evals/cases/YYYY-MM-DD-<slug>.md` in the skill folder:

```markdown
# <what this run did>
**Prompt:** <the request that started it, generalised>
**Setup:** <the state it starts from>
**Success:** <checkable properties of a correct result>
**Must not:** <each failure from this run, as an observable symptom>
```

Later failures add cases here, so a fix can be checked against every earlier run (`anthropic-skills:skill-creator` can run them as evals).

**Done when:** the case file exists and every "Must not" matches a rule in `SKILL.md`.

## 6. Place it and record it

- Used across projects → `~/.claude/skills/<name>/`. Only this repo → the project's `.claude/skills/<name>/`.
- User-level: add it to the "Not from any upstream" line in `~/.claude/skills/UPSTREAM.md`, so a sync never touches it.
- Mark any task-observer observation that proposed this skill `status: actioned` with today's date.
- Strip everything sensitive: no credentials, hostnames, patient data or client names in the skill or its case.

**Done when:** the files are in place, and the user has been shown the skill's steps and rules in a short summary.

## After the first real use

When the skill fails later, fix it the same way: find the step where it went wrong, add or sharpen the rule there, and add a case to `evals/cases/` for that failure. A fix without a case can quietly undo an earlier one.
