# `## Agent notes` — the per-project half of the user-level agents

The agents in `~/.claude/agents/` are generic. Each one reads the project's
`CLAUDE.md` and looks for an `## Agent notes` section for what is specific to
that repo. Copy the block below into a project's `CLAUDE.md` and fill it in.
Anything you leave out, the agents fall back on a sensible default for.

```markdown
## Agent notes

- **Run things with:** `uv run pytest ...`, `uv run python scripts/...`
- **Fast test loop (reviewer):** `uv run pytest -m "not slow"`
- **Test markers that gate data or hardware:** `needs_data`, `slow`, `needs_gpu`
- **Environment variables:** `PROJECT_DATA` — the data root; tests skip without it
- **Output directory (gitignored):** `out/runner/`
- **Named commands:** "the gate" = `uv run python scripts/gate.py`
- **Sensitive — never in a reply, file, diff or query:** patient identifiers,
  dataset filenames, case folder paths, session timestamps. Refer to cases by
  anonymised handle only.
- **Failure classes that matter most (silent-failure-hunter):** a wrong
  transform yields plausible, silently wrong output; defaults on measured
  values; fallbacks that skip a validity check.
- **Interface skill (ui-reviewer):** `.claude/skills/<name>/`
```

## Filled-in example: the spine / C-arm projects

These are the project details that used to be hard-coded in the agents,
moved here on 2026-09-24. Paste into those repos' `CLAUDE.md`:

```markdown
## Agent notes

- **Run things with:** `uv run` (`uv run pytest ...`, `uv run python scripts/...`)
- **Fast test loop (reviewer):** `uv run pytest -m "not slow"`
- **Test markers:** `needs_data`, `slow`, `needs_leap`, `needs_gpu` — a skip is a finding, not a pass
- **Environment variables:** `SPINE_*_DATA`
- **Output directory:** `out/runner/` or `outputs/runner/` (whichever is gitignored)
- **Named commands:** the bead gate; the real-mask correspondence test; evaluation over the dataset; sweeps over sessions
- **Sensitive:** patient identifiers, dataset filenames, case folder paths, session timestamps. Anonymised handles only.
- **Failure classes (silent-failure-hunter):**
  - a wrong affine produces an anatomically correct, silently mirrored volume
  - identity affine when a NIfTI header is missing
  - `np.nan_to_num` / `np.clip` / `np.nanmean` before the NaN is explained
  - a boundary vertebra kept because the removing check returned early
  - a frame conversion that assumes the input is already in the target frame
  - mesh or mask operations with no empty-result guard; resamples with no output-shape assertion
- **Reviewer scope:** geometry / ML / reconstruction changes always get a review
- **Interface skill (ui-reviewer):** the endoscopy application's `.claude/skills/qt-interface/`
```
