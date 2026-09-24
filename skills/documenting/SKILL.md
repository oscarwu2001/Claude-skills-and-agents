---
name: documenting
description: Write or update documentation grounded in the code — README, how-to guide, tutorial, API reference, explanation, docstrings, changelog. Use when the user asks to document something, write or fix docs, update a README, or explain code for other people. For a glossary or ADR coming out of a design conversation use domain-modeling; for a diagram use archify.
---

Documentation that is **grounded**: every statement traced to code, a command you ran, or a decision record — never to what the code probably does. A doc that is wrong gets believed, so grounded beats complete.

## 1. Pick the reader and the quadrant

Name the reader in one line (new contributor, API user, operator, future you) and the one **Diátaxis quadrant** the page serves:

| Quadrant | The reader wants to | Shape |
|---|---|---|
| Tutorial | learn by doing | one guaranteed-to-work path, start to finish |
| How-to | get a task done | numbered steps for one goal, prerequisites first |
| Reference | look something up | complete, dry, structured like the code it describes |
| Explanation | understand why | prose on design, trade-offs, history; links to ADRs |

One page, one quadrant. A request that spans two becomes two pages that link to each other.

**Done when:** reader and quadrant are written at the top of your working notes.

## 2. Find what already exists

Look for the docs home before writing: `README*`, `docs/`, `mkdocs.yml`, `docs/adr/`, `CONTEXT.md`, `CHANGELOG*`, docstring style in neighbouring code. Update the page that owns the topic rather than adding a second one; link to a fact's single source instead of restating it.

**Done when:** you can name the file you'll edit (or why a new one is needed) and the convention you're matching.

## 3. Ground every claim

Collect the facts from the code, not from memory — `graphify query` when `graphify-out/` exists, otherwise `Grep -n` on the exact symbol and `Read` around it. Take names, defaults, flags, env vars, types and error text verbatim from source. Take intent from ADRs, `CONTEXT.md` and commit messages; where intent isn't recorded, write what the code does and ask the user why.

**Done when:** every behavioural claim in your draft points at a `path:line`, a command output, or a decision record in your notes.

## 4. Write

- Lead with what the reader does or gets, in the first two lines.
- Use `CONTEXT.md` vocabulary; one name per concept throughout.
- Code blocks are copy-pasteable and complete: real paths, real flags, the prompt stripped.
- State prerequisites and versions once, near the top.
- Docstrings: what and why, arguments and units, what is raised; the signature already says the types.

## 5. Verify

- Run every read-only or sandboxed command and code example in the doc (long ones through the `runner` agent). A command with side effects — deploy, migrate, publish, delete, anything touching shared state — is not run: ask the user, or mark it not verified.
- Where an example and the code disagree, fix the doc. Changing the code is a separate decision for the user.
- Check every relative link and path resolves.
- For docstrings, compare each against its signature: every parameter present, none stale.

**Done when:** every safe example has been run on this checkout and every link resolves — list what you ran in your reply. An example you could not run is marked in the doc as not verified, with the reason.

## 6. Keep it attached to the code

Docs belong in the same change or PR as the code they describe. Generated reference (from docstrings, OpenAPI, `--help`) beats hand-written reference whenever the project can generate it — say so if it can't yet.
