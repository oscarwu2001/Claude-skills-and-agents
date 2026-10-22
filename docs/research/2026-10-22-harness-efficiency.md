# Which harness levers cut agent cost per task without lowering quality?

**Answer:** Best-supported levers: (1) keep the cached prefix stable (cache reads cost 0.05-0.1x, so breaks are the cost); (2) shrink standing context (shorter system prompt, tools loaded on demand, short CLAUDE.md); (3) clear or compact old tool output instead of carrying it. Cursor reports -7% total cost at no quality loss from these. Model routing has the largest cost effect in papers (35-85% on chat benchmarks) but agent-specific numbers are thin. The 200K/400K handoff thresholds have no primary source; the evidence says degradation is gradual and starts far earlier.
**Confidence:** medium. Anthropic and Cursor figures are vendor-reported with no methods; the independent papers are mostly not on Claude Code workloads.
**Applies to:** Claude API docs as of 2026-10 (Opus 5.5 / Sonnet 5.5 pricing); no project lockfile checked (research question, not code).

## Findings

### Prompt cache
- Write 1.25x (5 min TTL), 2x (1 h TTL); read/refresh 0.1x for most models, 0.05x on Opus 5.5 and Sonnet 5.5. Default TTL 5 min, refreshed free on each hit. [Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- Invalidation order is tools -> system -> messages. Changing tool definitions invalidates everything; changing thinking parameters or `output_config.effort` invalidates messages. Same page. Implication: switching effort mid-session, or editing tools/skills, re-writes the cache.
- Cursor: placing cache breakpoints and moving variable setup out of the stable prefix cut cold cache misses by 20%. No absolute hit rate published. [Cursor, improved token efficiency](https://cursor.com/blog/improved-token-efficiency)
- "~96% hit rate in Claude Code sessions" is from a third-party blog (Tunguz) via search snippet. Unverified, not fetched.
- Your 76% of cost as cache reads: at 0.05-0.1x that means volume (long contexts x many turns) is the driver, not misses. The lever is shorter context, or fewer turns at long context, not a better hit rate.

### Context rot and long-context degradation
- Chroma (Jul 2025): 18 models, 194,480 calls; every model scored higher on a ~300-token focused prompt than a ~113k-token full prompt on LongMemEval; distractors worsen it; non-uniform. Caveats: synthetic tasks, temperature 0, vendor in retrieval space, no replication. [Chroma Context Rot](https://www.trychroma.com/research/context-rot)
- Anthropic names the same effect and says it affects all models, with gentler slopes for some; no benchmark numbers given. [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- Lost in the Middle: accuracy drops when the relevant item is mid-context, even for long-context models. Abstract has no numbers; 2023 study on older models. [arXiv 2307.03172](https://arxiv.org/abs/2307.03172)
- Coding-specific: successful SWE-bench Verified agent trajectories typically stay under 20k tokens, and longer accumulated context correlates with lower success (correlational). Via search summary of [arXiv 2602.16069](https://arxiv.org/pdf/2602.16069); paper not read. Unverified.
- Thresholds: no source identifies 200K or 400K as a cliff. Chroma shows a gradual decline from short lengths. Your thresholds are a judgement call, not evidence-based. If anything the data favour earlier handoffs; none quantifies current Opus at 120-500K on coding tasks.

### Compaction and context editing
- Compaction summarises near the limit; Claude Code keeps decisions, bugs and the five most recent files. Tool-result clearing is the lightest form. Advice: tune for recall first, then precision. [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- Anthropic internal eval: context editing alone +29%, with memory tool +39% over baseline (agentic search); 84% fewer tokens in a 100-turn web-search eval, and workflows finished that otherwise failed. No sample sizes, "performance" undefined. Vendor. [Anthropic, context management](https://claude.com/blog/context-management)
- SWE-Compressor: 57.6% on SWE-bench Verified, +3.8-7.8 points over static compression / ReAct, bounded token growth. Secondary summary only. Unverified.
- No source compares compaction against fresh-session handoff directly. Unknown.

### Model mix and routing
- Anthropic multi-agent research system: Opus 4 lead plus Sonnet 4 subagents beat single-agent Opus 4 by 90.2% on an internal eval, at about 15x chat tokens (agents about 4x). Token usage alone explained 80% of variance on BrowseComp. A quality gain bought with more cost, not a saving; shows tokens drive quality. [Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system)
- RouteLLM: >85% cost cut on MT Bench, 45% MMLU, 35% GSM8K at 95% of GPT-4 quality (authors' figures, chat/QA, not agents; via search summary). FrugalGPT: up to 98% cost cut (authors' figures). Primary not fetched; Unverified.
- SWE-Router (arXiv 2607.00053): a cheap model runs a few exploratory turns, then the trajectory decides whether to escalate. Abstract says it "greatly improves the cost efficiency" while keeping "the majority" of the stronger model's performance. No numbers in the abstract; full text not read. [abstract](https://arxiv.org/abs/2607.00053). Closest agent-level evidence, and it implies some quality cost, not zero.
- Cursor Auto-mode claims (about 36-60% cheaper at similar satisfaction) came from a secondary article only. Unverified.

### Standing instructions
- IFScale ("How Many Instructions Can LLMs Follow at Once?"): 20 models, up to 500 instructions; best frontier models about 68% accuracy at 500; bias toward earlier instructions; decay shape depends on model size and reasoning. Synthetic keyword-inclusion task. [arXiv 2507.11538](https://arxiv.org/abs/2507.11538)
- AGENTS.md study (ETH/LogicStar, ICLR 2026): context files do not generally improve success and raise cost by over 20% on average; LLM-generated files +20-23%; human-written ones did slightly better (secondary summary: about +4%) but cost up to +19%. Recommends minimal requirements only. Abstract confirmed; per-file numbers from secondary summaries. [arXiv 2602.11988](https://arxiv.org/abs/2602.11988)
- Cursor trimmed its system prompt about 66% because newer models need fewer explicit instructions; tool descriptions -60% via dynamic loading; MCP dynamic loading -46.9% tokens in sessions that used one; each offloaded tool was needed in under 20% of conversations. Total effect on user cost: 7%, no quality loss, measured by A/B test on its user base (vendor). Components are separate measures; do not stack them. [Cursor](https://cursor.com/blog/improved-token-efficiency)
- Relevance: about 30 skills and a long CLAUDE.md table are standing context in the cached prefix, re-read every turn at 0.05-0.1x. Evidence on skill count specifically: none found.

## Conflicts and unknowns
- Cursor's "-7% without quality hit" is the only first-party figure found. OpenAI first-party numbers: not found (not searched deeply). Anthropic gives no cost-per-task figure for any harness lever.
- No source gives a cost-vs-quality curve for 120K-500K contexts on coding agents with current models. Would need your own A/B: handoff at 150K vs 300K, compare pass rate and cost.
- Pricing page read only to character 100,000 of 159,858.

## Open questions
- Does changing effort per turn break the cache in Claude Code (docs say effort change invalidates messages)?
- Do skill descriptions cost more than the CLAUDE.md table? Measure by token count.

## Dead ends
- Lost-in-the-Middle, RouteLLM and FrugalGPT abstracts carry no agent-level numbers.
- Search for cost-per-resolved-issue studies: none found.
- The Cursor conference talk itself not located; the blog above is the likely first-party source.
