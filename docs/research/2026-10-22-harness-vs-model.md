# Does harness/scaffold choice still change coding-benchmark success and cost for frontier models (2025-2026)?

**Why asked:** decide whether to cut coding-specific instructions (exploration ladder, forced TDD/implement skills, routing tables) from a personal Claude Code setup in favour of a thin harness.
**Done when:** both talk-cited papers are read first-hand, plus independent first-party evidence.

**Answer:** For current frontier models on SWE-bench-style and MLE tasks, harness choice moves success rate little (mostly within noise, about +/-5 pp at the sample sizes used) but moves cost per task a lot (about 1.0x-5.1x). The gap between a bare bash/minimal agent and the best custom scaffold has shrunk from about 12-14 pp (Claude 3.7/4 Sonnet era) to about 2-5 pp (Claude 4.5). Caveat that matters for you: none of this tests user-level CLAUDE.md/skill instructions (TDD, lookup ladders). It tests whole-harness defaults (tools, built-in system prompt) and orchestration layers. Applying it to your instructions is inference, not measurement.
**Confidence:** medium-high on "success flat, cost varies" (two independent controlled studies plus leaderboard trend); low on anything specific to user-written instructions.
**Applies to:** HarnessTax (Claude Code 2.1.224, Codex CLI 0.146.0, Pi 0.85.1; Sep 2026 models); Apple/EPFL (OpenCode v1.15.6, open-weight backbones); SWE-bench leaderboard snapshot pulled 2026-10-22.

## 1. The two talk-cited papers (both found, read first-hand)

### (1) "HarnessTax: How Much Does the Harness Matter for Coding Agents?" (the "UC Berkeley" study)
- Authors (per Tom Tunguz's citation, not the page): Melissa Z. Pan, Shuo Yang, Negar Arabzadeh, Wei-Lin Chiang, Ion Stoica, Matei Zaharia. UC Berkeley Sky Lab + Arena, released about 2026-09-16. Project page https://harnesstax.github.io/ and https://arena.ai/blog/coding-agents-harness-tax/. **No arXiv ID found**; it is a web report, not a peer-reviewed paper.
- I read the raw chart JSON behind the project page (e.g. https://harnesstax.github.io/data/charts/system-harness-effect-swe.f233b4a6e8.json), so numbers below are first-hand, not from blog summaries.
- Design: 7 models (Claude Fable 5, Opus 4.8, Sonnet 4.6, Haiku 4.5; GPT-5.6 Sol, Luna; Kimi K3) x 3 harnesses (Claude Code, Codex CLI, Pi = 4 tools read/write/edit/bash) = 21 pairs. 30 sampled tasks per benchmark (SWE-bench Lite, Terminal-Bench 2.0), 3 attempts each; cost modeled from a fixed price list dated 2026-09-01.
- First-call context: Pi 4 tools / ~2.0k tokens; Codex 7.4 tools / ~11.3k; Claude Code 23 tools / ~27.0k (https://harnesstax.github.io/data/charts/system-agent-context-swe.06f521bdb1.json).

**Success (SWE-bench Lite), difference vs Pi in pp, 95% CI in brackets where noted:**

| Model | Claude Code - Pi | Codex - Pi |
|---|---|---|
| Fable 5 | +1.1 [-3.3, +6.7] | 0.0 |
| Opus 4.8 | +4.4 [+1.1, +8.9], p=0.022, Holm p=0.43 | +6.7 [+2.2, +11.1], p=0.002, Holm p=0.042 |
| Sonnet 4.6 | +2.2 | +4.4 |
| Haiku 4.5 | -7.8 [-16.7, 0.0], p=0.049, Holm 0.93 | -2.2 |
| GPT-5.6 Sol | +3.3 | -1.1 |
| GPT-5.6 Luna | +2.2 | +2.2 |
| Kimi K3 | +4.4 | +2.2 |

- Only one of 14 SWE comparisons survives Holm correction (Opus 4.8, Codex over Pi, +6.7 pp). Everything else is within noise. Direction is mixed, not "Pi wins": the heavier harnesses are slightly ahead on 11 of 14.
- Terminal-Bench 2.0 (descriptive only, no confirmatory test): Claude Code - Pi ranges +4.4 (Fable 5) to -6.7 (Haiku 4.5); CIs all cover zero. Codex - Pi for GPT-5.6 Sol and Luna: -4.4 each.
- Discrepancy: Tunguz's post says none of 42 comparisons survived Holm; the SWE JSON shows one that does (Holm p=0.042). Sources not reconciled (Holm family size may differ by cohort).

**Cost per task, ratio vs Pi (SWE-bench Lite):**

| Model | Claude Code / Pi | Codex / Pi | Absolute (CC vs Pi) |
|---|---|---|---|
| Fable 5 | 2.00 (CI 1.76-2.33) | 1.34 | $1.33 vs $0.67 |
| Opus 4.8 | 2.06 | 1.47 | $0.98 vs $0.47 |
| Sonnet 4.6 | 0.99 (n.s.) | 1.10 | $0.67 vs $0.68 |
| Haiku 4.5 | 1.14 (n.s.) | 1.05 | $0.43 vs $0.37 |
| GPT-5.6 Sol | 3.50 | 1.27 | $1.54 vs $0.44 |
| GPT-5.6 Luna | 5.09 | 1.18 | $0.15 vs $0.03 |
| Kimi K3 | 1.72 | 1.86 | $0.78 vs $0.46 |

- Terminal-Bench 2.0 CC/Pi: Fable 1.44, Opus 1.19, Sonnet 1.09, Haiku 1.05; Codex/Pi: Sol 1.81, Luna 1.41.
- So the talk's claim (1) is confirmed in direction. Cost penalty is large for frontier tiers and for GPT models in Claude Code, near zero for Sonnet 4.6/Haiku 4.5. The "5x" headline is the single most extreme row (Luna, in absolute terms pennies).
- Caveats: n=30 tasks per benchmark, so detectable success difference is roughly 5 pp or more; Fable 5 scores about 97% on Lite (ceiling effect hides any harness benefit); SWE-bench Lite is public and likely contaminated; Terminal-Bench run had a 100-turn cap; the authors' own caveat is that proprietary/unseen codebases might favour richer harnesses; traces for all 21 pairs not yet published (via braindetox.kr summary of the post, secondary). Arena is a model-eval company, not neutral on "which model" but has no stake in a specific harness that I could find.

### (2) "How Much of a Harness Does a Strong Agent Need for Autonomous ML Engineering?" (the "Apple/EPFL" study)
- Brilliantov, Hernandez-Cano, Abbe; EPFL and Apple (interns; Apple affiliation is for work done during internship). arXiv 2609.40303, v1 2026-09-30. Read first-hand from the PDF (https://arxiv.org/abs/2609.40303).
- Design: a single minimal agent, "Malena" (OpenCode v1.15.6 session with read/write/bash, one well-prompted session), vs four open-source MLE harnesses (MLEvolve, AiScientist, Arbor, ScienceFlow) on 30 MLE-bench tasks (fixed30) and 40 NatureBench tasks, 24 h budget, 3-4 seeds per task, 95% bootstrap CIs.
- **Backbones are open-weight models** (GLM 5.2, Kimi K3, DeepSeek V4 Flash, Gemma 4 31B, GPT-OSS 120B), not Claude/GPT. "Frontier" here means frontier open-weight.
- Results: Malena matches or beats every harness on every tested pair (17 pairs MLE-bench, 6 NatureBench). Only exception: weakest backbone (Gemma 4 31B), where MLEvolve is ahead on percentile with overlapping medal-rate CIs. NatureBench "surpassed SOTA": GLM-5.2 Malena 21.7% vs AiScientist 17.5% vs MLEvolve 10.8%; Kimi-K3 26.7% vs 27.1% vs 11.7%.
- Ablation ladder: moving from chat to a coding-agent environment is "by far the largest effect"; adding search strategies (Greedy/UCB1/Best-of-N), autonomy, or multi-agent orchestration gives no statistically significant gain (largest gap in the search ablation: +2.71 pp, CI -1.44 to +6.60). Parallel multi-agent raised the oracle ceiling but lowered self-selected results.
- **Cost: opposite to the talk's implied direction.** The minimal single-session agent was the most expensive on cost: at GLM 5.2, Malena $12.12 modeled vs AiScientist $1.95 (6.2x), because one ever-growing session resends cache-read tokens. Cache-read cost is modeled at 0.1x input price (no harness reports real cache hits). So "cost differs" is true, but here simple = costlier. Treat the talk's cost framing as unconfirmed for this paper.
- Author caveats: MLE-bench has task-prep bugs and likely contamination (checked with two similarity methods, none found); CIs wide, only "no worse than" claims are well supported; Malena is the authors' own system (tuning asymmetry risk, mitigated by tuning ablations on rivals); single-worker scope.

## 2. Other first-party evidence

- **SWE-bench Verified leaderboard, same model across scaffolds** (pulled from https://github.com/SWE-bench/swe-bench.github.io `data/leaderboards.json` on 2026-10-22; "resolved" %):
  - Claude 3.7 Sonnet: best custom 66.4 vs mini-SWE-agent 52.8 (gap 13.6 pp).
  - Claude 4 Sonnet: best 76.8 (EPAM) vs mini-SWE-agent 64.9 / SWE-agent 66.6 (gap about 10-12 pp).
  - Claude 4.5 Sonnet: best 74.8 (Sonar) vs mini-SWE-agent 70.6-71.4 (gap 3.4-4.2 pp).
  - Claude 4.5 Opus: best 79.2 (Sonar, live-SWE-agent) vs mini-SWE-agent 74.4 (verified run) / 76.8 (later run) (gap 2.4-4.8 pp).
  - GPT 5.2 (mini-SWE-agent only): 69.0-72.8, cost $0.27-0.52 per instance. Claude 4.5 Opus via mini: $0.72-0.75 per instance.
  - Caveats: most custom-agent rows are `checked: false` (self-reported), different attempt counts and test-time tricks, no cost field for them, so cost per task cannot be compared; the Verified set is contaminated/audited (OpenAI reportedly stopped reporting it in Feb 2026, from a search summary; not read first-hand).
- **mini-SWE-agent** (Princeton/Stanford SWE-bench team): agent class is about 100 lines, bash only, linear history; README claims ">74% on SWE-bench Verified" and "what if our agent was 100x simpler and still worked nearly as well?" (https://github.com/SWE-agent/mini-swe-agent README). README also says "a lot of this [tools/special interfaces] is not needed at all" as LMs improved. Vendor-neutral but the authors are the SWE-agent team arguing their own thesis. Its README also claims it beats Claude Code and Codex on DeepSWE; **Unverified** (not fetched).
- **SWE-agent ACI paper** (Yang et al., arXiv 2405.15793, 2024, GPT-4 Turbo / Claude 3 Opus): custom agent-computer interface gave +10.7 pp over a shell-only agent on SWE-bench Lite (18.0% vs 7.3%, "64% relative" in the paper's text; the 7.3 figure is derived). This is the strongest evidence FOR harness value, but it is on 2024 models scoring 12-18%. The leaderboard trend above shows that gap collapsing with newer models.
- **Agentless** (arXiv 2407.01489, 2024): non-agentic three-phase pipeline 32.00% on Lite at $0.70 per issue, beating open-source agents then. Supports "simple + cheap competes", era GPT-4o. Not informative about 2026 models.
- **Sghaier, Li, Adams, Hassan, "Don't Blame the LLM: How Agent Harness Evolution Shapes Coding Agent Quality"** (arXiv 2607.03691, July 2026): fixed model (Qwen3-Next-80B-A3B), 35 sequential Qwen Code releases, 50 SWE-bench Verified tasks: no statistically significant improvement in resolve rate across releases; later releases use nearly double the tokens and tool calls. Narrow (one harness, one small open model, 50 tasks). Note: Apple/EPFL paper cites this as evidence that harness releases do not improve scores; it matches.
- **"Harness or Model?"** (Arjmandi, arXiv 2609.11987, 2026-09-08, single author, private 256-task suite): vendor-native vs neutral harness, same model. Opus 4.8 48.8% (native) vs 50.0% (neutral), -1.25 pp [-10.0, +7.5]; GPT-5.5 55.6% vs 54.4%. Task-type split for Opus: repo tasks native -9.0 pp, contest tasks +23.7 pp (post-hoc, p=0.003, author says needs replication). Neutral harness cost 1.2-1.6x as much per solved task, but 58 Anthropic runs lack usage data, so the Opus cost ratio range is 0.7-2.3 (author: unresolved). Opposite cost direction to HarnessTax. Evidence quality: small, single author.
- **Counter-evidence: Terminal-Bench 2.0.** Han and Sun, "How good is your harness?" (ICML 2026 workshop): on TB 2.0 "the harness matters as much as the LLM" and effects are model-harness heterogeneous (abstract only, no numbers read; https://icml.cc/virtual/2026/68323). A secondary blog (https://codex.danielvaughan.com/2026/04/09/harness-performance-terminal-bench/) lists Claude Opus 4.6 at 58.0% in Claude Code vs 74.7% in Terminus-KIRA, 81.8% ForgeCode (self-reported/secondary). **Unverified**: I could not load the tbench.ai leaderboard rows (dynamic page). These gaps (16-24 pp) conflict with HarnessTax's TB2 gaps (<=7 pp, n=30), but the public leaderboard compares different harness implementations, prompts, budgets and run dates, so it is observational, and the harnesses are tuned specifically for that benchmark. Resolution not possible from what I fetched.
- **Anthropic: trimming Claude Code's system prompt.** Speakers Cat Wu and Thariq Shihipar, AI Engineer World's Fair; Simon Willison's transcript 2026-07-21 (https://simonwillison.net/2026/Jul/21/cat-and-thariq/): notes say the prompt "recently reduced in size by 80%"; Cat: "It's only our most frontier models that have this 80% token decrease"; Thariq: earlier (Opus 4-ish) models "wanted a lot of examples, and removing examples was extremely helpful"; "fewer hard constraints, more context, and fewer instructions overall." This is a talk, not an engineering post, with no eval numbers. Independent measurement (https://github.com/phuryn/experiments/tree/main/claude-code-system-prompt-shrink): about 70% defensible (2,686 words in Apr to 830 words with memory loaded in Jul; part of the cut is moved to load-on-demand); the same-day capture shows Sonnet 5 and Haiku 4.5 still get 2,094 words versus 383-901 for Opus 4.8/Fable 5 (so the trim is model-tiered); no task-success measurement. Claims of "no measurable loss on coding evals" come from secondary coverage (cryptobriefing, Jul 25), **Unverified**. Anthropic's own postmortem (https://www.anthropic.com/engineering/april-23-postmortem) shows the opposite risk: a verbosity-reducing system prompt line hurt coding quality and was reverted 2026-04-20 (title read via search only).
- **Cursor.** Secondary summary (https://www.startuphub.ai/ai-news/technology/2026/cursor-s-agent-harness-gets-smarter.md): early guardrails such as surfacing lint errors after each edit and static codebase-structure context are being removed as models improve, replaced by dynamic on-demand context; edit tools matched per model (patch vs string-replace). No measured effect sizes. The "removed separate apply-edit model" claim: **not found in any source I fetched**; original Cursor post not located.

## 3. Synthesis (inference, flagged)
- Supported: on current frontier models, orchestration layers, search strategies, multi-agent scaffolds, and heavy default harnesses do not reliably add pass rate; the big step is "model in a real tool-using environment with bash/read/write" (Apple/EPFL ladder), which Claude Code already gives you.
- Supported: harness weight shows up mainly as cost (first-call context 2k vs 27k tokens; up to 3.5-5x on some models; none for Sonnet 4.6/Haiku 4.5), with exceptions where the minimal agent is costlier (Apple/EPFL cache-read effect; Arjmandi).
- Inference, unmeasured: your CLAUDE.md prompts (exploration ladder, forced TDD, routing tables) behave like the prompt-side content Anthropic says it trimmed for frontier models (examples, hard constraints). Nothing here shows they raise or lower pass rate. What the evidence does support is that they add per-turn tokens (cost) and that benefit, if any, is task-type dependent (Arjmandi's split) and model-tier dependent (Haiku/Sonnet-tier still get longer prompts from Anthropic).
- Not tested anywhere I found: TDD-forcing, human-in-the-loop workflows, long-lived multi-session repos, proprietary codebases (HarnessTax names the last as a limit).

## Conflicts and unknowns
- HarnessTax Holm result: JSON shows one significant success difference; Tunguz says none. Not reconciled.
- Terminal-Bench 16-24 pp harness gaps (secondary, leaderboard) vs <=7 pp in controlled HarnessTax. Settle by fetching tbench.ai leaderboard rows (needs browser/API).
- Cost direction differs by study: HarnessTax (heavy harness costlier), Apple/EPFL (minimal single session costlier), Arjmandi (neutral costlier, uncertain).
- Anthropic's "no loss on evals" claim has no primary eval artefact.
- Cursor apply-model removal: no source.

## Open questions
- Does any study ablate user-level instruction files (CLAUDE.md, skills) on success and cost? None found in this pass.
- Does TDD-forcing change success on real repos with current models?

## Dead ends
- arena.ai blog and harnesstax.github.io via WebFetch: JS-rendered, empty. Fixed by curl of the chart JSON files.
- tbench.ai leaderboard via WebFetch: table rendered empty.
- https://www.swebench.com/bash-only.html: 404; the leaderboards.json on GitHub worked instead.
- Searching for Cursor "apply model" removal: nothing.
- arXiv API search for "HarnessTax": 0 results (not on arXiv as far as I could find).
- Not read first-hand: Meta-Harness (Stanford IRIS), ForgeCode, Terminus-KIRA, DeepSWE, OpenAI engineering posts on scaffolding removal (no search done; out of budget).
