# Does coordinator+workers, separate review, or execution-based verification pay for itself in coding agents?

**Question:** What does first-party 2024-2026 evidence say about (a) coordinator+workers vs one agent, (b) separate reviewer agents, same-model vs different-model review, (c) execution-based verification, each against token cost?
**Why asked:** reshape a pipeline of Opus builder phases + 1-4 review agents each (~26% of helper spend on review; Sonnet reviewer FAIL 17/40).
**Done when:** primary sources with effect sizes and cost multiples. Method: abstracts/HTML pages fetched and read via a summarising fetch tool, so numbers below are as extracted by that tool; re-check any you build on.
**Versions:** not project-specific; papers dated in each line.

**Answer:** (1) For coding, multi-agent coordination buys little to nothing and costs 1.6-6x tokens; the best case is parallelisable work, not sequential build phases. (2) A separate, skeptical evaluator beats self-review, but only when it executes the app (Playwright) and is tuned; reading-only LLM review has high false-accept/false-reject rates. (3) Execution-based checks and LLM review are complementary; combining beat either alone (42-43% each, 51% combined). (4) The pstack "model diversity, not personas" claim is an unsupported assertion in the skill text; no paper found that tests it directly, and some evidence cuts against it.
**Confidence:** medium. Strong on cost multiples and single-vs-multi; thin on "diverse reviewer models for code review" and on any PR-level reviewer study.
**Applies to:** 2024-2026 papers and vendor posts; models mostly GPT-4o/Claude 3.7-Opus 4.6 era.

## Findings

### A. Coordinator + workers vs one agent
- Anthropic research system: agents use ~4x chat tokens, multi-agent ~15x; Opus 4 lead + Sonnet 4 subagents beat single Opus 4 by 90.2% on an internal research eval; token usage alone explained 80% of BrowseComp variance (tools + model choice bring it to 95%). The post itself says coding has "fewer truly parallelizable tasks than research" and that domains needing shared context are poor fits. VENDOR, internal eval, research not coding. [anthropic.com/engineering/multi-agent-research-system](https://www.anthropic.com/engineering/multi-agent-research-system)
- Google/MIT scaling study (arXiv 2512.08296, Dec 2025, 260 configs, 6 benchmarks): on SWE-bench Verified every multi-agent variant scored below single agent (0.522): hybrid -2.1%, centralized -3.1%, decentralized -5.4%, independent -14.9%. Token overhead vs single agent: independent +58%, decentralized +263%, centralized +285%, hybrid +515% (1.6-6.2x). Success per 1K tokens: single 67.7 vs centralized 21.5. Rule of thumb from the paper: once single-agent accuracy exceeds ~45%, extra agents give negative returns (beta -0.236, p=0.004). Sequential planning task: -39% to -70%; parallelisable finance task: +80.8%. Error amplification: independent 17.2x, centralized 4.4x (a coordinator that validates helps, but does not beat one agent). Academic, benchmark-based. [arxiv.org/abs/2512.08296](https://arxiv.org/abs/2512.08296), [html](https://arxiv.org/html/2512.08296)
- Cognition "Don't Build Multi-Agents" (2025): principles "share full agent traces" and "actions carry implicit decisions"; prefer single-threaded linear agent, compress history for long tasks. No numbers at all; reasoning plus one anecdote. VENDOR OPINION. [cognition.com/blog/dont-build-multi-agents](https://cognition.com/blog/dont-build-multi-agents)
- Cursor "Scaling long-running autonomous coding" (Jan 2026): flat/lock-based coordination failed (20 agents ran at throughput of 2-3); an integrator/QC role "created more bottlenecks than it solved"; hierarchical planner->worker with a judge that ends each cycle worked; prompts mattered more than harness; periodic fresh starts needed against drift. Trillions of tokens, no cost or quality numbers; says the Solid-to-React migration "still needs careful review". VENDOR, no controlled comparison. [cursor.com/blog/scaling-agents](https://cursor.com/blog/scaling-agents)
- MAST (arXiv 2503.13657, 1,642 traces, 7 frameworks): failure modes sum to ~44% system design, ~32% inter-agent misalignment, ~24% task verification (my sums of listed mode rates; paper does not state totals). Prompt/role fixes on ChatDev gave +9.4% task success; adding a high-level verification step +15.6% (ProgramDev), partial gains only. Academic (older models: GPT-4o, Claude 3.7). [arxiv.org/abs/2503.13657](https://arxiv.org/abs/2503.13657), [html v3](https://arxiv.org/html/2503.13657v3)

### B. Separate reviewer vs self-review, same vs different model
- Anthropic harness post (planner/generator/evaluator): solo Opus 4.5 run 20 min / $9, core feature broken; full harness 6 h / $200 (>20x) and worked. Then with Opus 4.6 the author removed sprints, moved the evaluator to one pass at the end, kept the planner; "evaluator is worth the cost when a task is beyond what the model does reliably alone". Out of the box Claude as QA "talked itself into approving"; tuning a standalone skeptical evaluator was "far more tractable" than making a generator self-critical; evaluator used Playwright to click through the live app. DAW run: $124.70 total, QA rounds ~$3-4 each vs build rounds $37-71. VENDOR, n=few demos. [anthropic.com/engineering/harness-design-long-running-apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- Self-correction: without external feedback, LLMs often fail to self-correct reasoning and can get worse; gains in earlier work came from oracle labels (Huang et al., ICLR 2024, arXiv 2310.01798). [arxiv.org/abs/2310.01798](https://arxiv.org/abs/2310.01798)
- Code self-repair: gains modest or absent once repair cost counted; bottleneck is the model's feedback on its own code; a stronger model giving feedback gave much larger gains (Olausson et al., ICLR 2024, arXiv 2306.09896; GPT-3.5/4, HumanEval/APPS - old models). [arxiv.org/abs/2306.09896](https://arxiv.org/abs/2306.09896)
- Self-preference: GPT-4 and Llama 2 recognise their own output above chance, and bias scales linearly with self-recognition (Panickssery et al., NeurIPS 2024, arXiv 2404.13076). [arxiv.org/abs/2404.13076](https://arxiv.org/abs/2404.13076)
- Errors correlate across models: ~60% agreement when two models both err on one leaderboard; stronger for same provider/architecture (Kim et al., arXiv 2506.07962). A May 2026 preprint finds 9 frontier judges from 7 families give only ~2 effective votes, and the best single judge matched or beat the panel (Kohli, arXiv 2605.29800) - single new preprint, weak confidence. [2506.07962](https://arxiv.org/html/2506.07962v1), [2605.29800](https://machinelearning.apple.com/research/correlated-llm-evaluation-panels)
- Reading-only LLM judging of code is unreliable: high false rejection of correct code, worse with elaborate prompts (arXiv 2603.00539); GPT-4.1-mini judge ~23% false positives / 16% false negatives, small models worse (arXiv 2602.11911); an LLM judge is "useful for triage but not a standalone correctness oracle" for patches, biased by "all tests passed" statements (ESEM 2026, Zhan et al.). Benchmark tasks, not PR review. [2603.00539](https://arxiv.org/pdf/2603.00539), [2602.11911](https://arxiv.org/pdf/2602.11911), [ESEM](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ESEM.2026.21)
- CriticGPT (OpenAI, 2024): model critiques preferred over human critiques in 63% of naturally occurring LLM-error cases; critics hallucinate bugs, human+critic teams hallucinate less. Trained critic, not a prompt. VENDOR. [arxiv.org/abs/2407.00215](https://arxiv.org/abs/2407.00215)

### C. Execution-based verification
- R2E-Gym (arXiv 2504.07164): execution-based verifier and execution-free (LLM) verifier each saturate ~42-43% on SWE-bench Verified; hybrid reaches 51%. Execution-based has low distinguishability; LLM verifiers "biased, rely on stylistic features". Academic, open 32B model. [arxiv.org/abs/2504.07164](https://arxiv.org/pdf/2504.07164)
- CodeT (2022, old): test-based reranking lifted HumanEval pass@1 to 65.8% (+18.8 abs over code-davinci-002). [arxiv.org/abs/2207.10397](https://arxiv.org/abs/2207.10397)
- Agent-written tests (arXiv 2602.07900, Feb 2026, six LLMs, SWE-bench Verified): resolved and unresolved tasks wrote tests at similar rates; prompting agents to write more or fewer tests did not significantly change outcomes; mostly print statements, not assertions. A model that wrote almost no tests matched top agents. I.e. tests the builder writes for itself are not the lever; extra tokens only. [arxiv.org/abs/2602.07900](https://arxiv.org/abs/2602.07900)
- MAST: ChatDev verifiers often only checked compilation/TODOs; a chess app passed review yet had runtime bugs; recommends multi-level verification (low-level + goal-level). [html v3](https://arxiv.org/html/2503.13657v3)
- Anthropic harness evaluator drove the live app with Playwright, with hard per-criterion thresholds (any fail = sprint fails). Closest vendor evidence for "run it, don't read it". See B.

### D. pstack "model diversity, not personas"
- The claim is in Cursor's pstack `/interrogate` skill text: "The adversarial signal comes from model diversity, not assigned personas." The page offers no data or citation (visible portion only). [skills.sh/cursor/plugins/interrogate](https://www.skills.sh/cursor/plugins/interrogate)
- Supporting indirect: correlated-error and self-preference papers (B) imply same-model review shares blind spots; Olausson shows a stronger feedback model helps.
- Against or neutral: Self-MoA (Li et al., arXiv 2502.00674, TMLR 2026) found sampling the single best model beat mixing different models by +6.6% (AlpacaEval 2) and +3.8% avg (MMLU/CRUX/MATH) because mixing lowers average quality; Kohli 2026 found cross-family panels ~2 effective votes. "Debate or Vote" (2508.17536) found persona-heterogeneous debate mostly paralleled majority voting. Those are not code-review studies.
- No 2x2 (same/mixed model x persona/none, matched compute) on code review found. Verdict: plausible, unproven; a different model helps mainly if it is at least as strong as the author.

## Reading for the pipeline (my inference, not a source claim)
- 102 builds vs 205 reviews with 1-4 reviewers: evidence says marginal reviewer #2-#4 on the same diff has correlated errors, so expect diminishing returns; merging into one reviewer with an execution step is better supported than stacking reviewers.
- Reading-only review should be triage; the verdict-bearing check should run tests/app and give before/after evidence.
- Sonnet FAIL 17/40 is uninterpretable without ground truth (could be real catches or overcorrection; 2603.00539 shows overcorrection is a known LLM failure). Sample ~10 FAILs and check them against a run.
- Coordinator+builder in series is the sequential pattern where Google's data shows no gain; Cursor and Anthropic both show coordination layers being pruned as models improved.

## Conflicts and unknowns
- Anthropic harness: evaluator essential (Opus 4.5) vs mostly unnecessary (Opus 4.6); effect depends on model and task edge. Re-test as models change.
- Google paper's coding result is SWE-bench-style single-issue tasks, not 35-minute multi-file build phases; transfer is Unverified.
- No first-party study found of PR-level AI reviewer precision/recall with cost. Unverified whether MAST/Google token multiples hold for review-only agents.
- Google paper: only abstract and first ~100K chars of HTML read; MAST html first 100K of 162K chars read.
- Cursor and Cognition posts: no quantitative evidence.

## Open questions
- Does a cross-model reviewer (e.g. a different vendor) beat a second same-model reviewer on code? No direct evidence found.
- Cost curve of an execution-verification step vs reviewer agents in this pipeline: needs own measurement.

## Dead ends
- arxiv.org/pdf/2503.13657 via fetch tool - compressed PDF unreadable; use html v3.
- Searches for a persona-vs-model 2x2 ablation and for PR-level AI reviewer studies - nothing direct.
- SWE-Gym verifier numbers - not retrieved.
- AlphaCodium, Agentless - not fetched (budget); unread.
