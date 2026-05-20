# Phase 3 — LoRA fine-tune for wrap-up coherence and multi-turn fabrication suppression

Living planning document. Updated as sub-phases complete. Fresh sessions should read this in full before acting on any Phase 3 directive.

## Goal

Train a LoRA adapter on top of `llama3.1:8b` that addresses the failure modes Phase 2B established as weight-level (not addressable by Modelfile SYSTEM iteration):

- **Multi-turn fabrication** — the model claiming actions that didn't fire, with the claim subsequently stored in `/history.json` as established assistant content and reinforcing the failure on later turns.
- **Pseudo-prose wrap-ups** — Python-pseudo-prose like `(led_set(r=255, g=0, b=0))` rendered in user-facing Telegram replies despite Modelfile SYSTEM directly prohibiting it.
- **Tool-name collision under multi-call contexts** — the model emitting one tool's argument shape with a different tool's name slot (smoke #4 in Phase 2B: led_set RGB args under `file_read` function name).

The output is `wireclaw-agent:v2` — same Modelfile shape as v1 plus `ADAPTER ./lora-wireclaw-v2/` directive pointing at the trained adapter.

## Why LoRA specifically

Phase 2 sequence established empirically that each layer of the stack fixes failure modes one level "more contextual" than the layer before. System prompts fix per-turn classification ("which tool for this message"). They cannot fix cross-turn behavior ("don't claim things that didn't happen") because conversation history is generated from the model's prior outputs and the system prompt cannot retroactively modify cached outputs.

LoRA changes weights. Behavior trained into weights is invariant across context length, conversation history, and prompt variation because it's structural. "Don't fabricate action narrations" is the exact kind of cross-context invariant weight-level training is uniquely suited for.

The framing carried forward: **LoRA for the invariants, SYSTEM for the operator-configurable surface.** Identity and constitution stay in SYSTEM (operator-editable). Tool examples stay in SYSTEM (registry-specific). Behavioral invariants like "respond honestly," "don't claim what didn't happen," "use plain English wrap-ups never pseudo-prose" go in weights via LoRA.

## Resources

Mapped to pipeline stages. All resources Scott already owns plus modest additions.

**Edge / data-capture layer:**
- ESP32-C6 boards. Currently 1 in active dev service (board 1, baseline) + 1 in production capture (Pilot, on `wdl-v1`) + ~7 spares. **Target capture topology revised 2026-05-15 to 3 active capture chips, not 7** — see "Hardware scaling math" below for the GPU-saturation argument. Each capture board serves as a parallel endpoint into azza's Ollama; beyond ~3, additional chips queue rather than add throughput.
- Raspberry Pi 3 cluster: 7 units total. **Active topology revised 2026-05-15: 3 driver Pis (one per active capture chip) + 1 "status display" Pi as the 4th rack unit (live dashboard / raw serial / corpus stats — application TBD) + 3 spares.** Currently 1 driver Pi online (`evobot`, `192.168.1.51`) with the Phase 3.1 software stack and the Telethon synthetic-user driver. Each driver Pi runs one persona module per session; persona variety across the fleet via rotation rather than chip count.
- Synthetic-user persona diversity: non-technical user, power user, ambiguity tester, time-based-rule specialist, memory-recall specialist, etc. One persona per Pi.

**Compute layer:**
- GTX 1080 (azza, 8 GB VRAM): inference host for the current bake; continues serving wireclaw-agent:v1 + future v2.
- GTX 1070 ("k-scale-trainer", 8 GB VRAM, Pascal sm_61): **prepped 2026-05-15.** Ubuntu 24.04.3, i5-4590, 23 GB RAM, driver 580.95.05, reachable keyless on the tailnet as `scott@k-scale-trainer`. Hosts Phase 3.3 training via the pinned peft+bnb recipe (see Phase 3.3 + `RIG.md`). Powered down between training cycles.
- Cloud GPU (Brev or similar): burst capacity for rank-sweep experiments and validation that local training matches cloud. A100-80GB at ~$1-2/hour, total project cost estimated $20-50.
- Spare PCs: orchestration of Pi fleet, NFS/Postgres for corpus store, eval monitoring. Off Scott's main workstation.

**Labeling layer:**
- Claude API: tiered usage. Haiku for bulk first-pass wrap-up classification. Sonnet for borderline cases. Opus for synthesizing corrected wrap-up targets on fabrication cases. Project budget estimate: under $100 total.

**Total operating cost estimate for Phase 3:** under $200 (Claude API + cloud bursts + electricity + the ESP32-C6 boards Scott already has). Capital cost: zero new GPU purchases (current 1080 + 1070 are sufficient). PoE HAT cost for the 3-active-Pi topology is ~$75 (3 × $25 vs. the original 7-chip plan's $175).

## Hardware scaling math and target topology

**Decision (2026-05-15):** target **3 active capture pairs** (Pi + ESP32-C6) plus
**1 status-display rack unit**, not the originally-planned 7 capture pairs.
Driver: azza's GTX 1080 is the throughput ceiling, not the chip count.

**The arithmetic** (from the 2026-05-15 3.1.1 single-pair session + overnight observation):

- One chip drives ~140 turns/hour, each turn = 2 LLM calls. Single-chip Ollama call rate ~280/hour.
- Per-call latency (3.1.1 19-record session): mean 3.4 s, p50 4.6 s, p95 7.7 s.
- Single-chip GPU duty cycle: ~5 s/call × 280/hour ÷ 3600 = ~39%. Plenty of headroom on one chip.
- Ollama 0.x defaults to **`OLLAMA_NUM_PARALLEL=1`** — requests for the same model serialise on the GPU. Theoretical ceiling: 1 call / 5 s = ~720 calls/hour = ~360 turns/hour aggregate across all chips.

| Active chips | Aggregate turns/hour | GPU duty cycle | Per-chip turns/hour |
|---|---|---|---|
| 1 | ~140 | 39% | 140 |
| 2 | ~280 | 78% | 140 |
| **3** | **~360 (saturated)** | **~100%** | **120** |
| 4+ | ~360 (capped) | 100% (queue grows) | drops as queue depth grows |
| 7 | ~360 (no gain) | 100% (deep queue, latency p95 blows) | ~50 |

**Saturation point is ~3 chips on the GTX 1080.** Adding chips past that adds queue
depth, not data. The "more variety" benefit of running 7 personas in parallel
is obtainable from 3 chips × persona rotation across sessions, in the same wall clock.

**Levers to push the ceiling later** (none required for the v2 corpus target):

1. **`OLLAMA_NUM_PARALLEL=2` on azza.** Cheap experiment after the overnight.
   Whether the 8B + 2 concurrent contexts fits in 8 GB Pascal VRAM is the open
   question. If yes, ceiling doubles to ~6 useful chips.
2. **k-scale-trainer (1070) as a second Ollama inference host** on nights it
   isn't training. Doubles theoretical capacity; adds operational complexity
   (split the fleet across two endpoints; same bake on both).
3. **Just run longer.** 3 chips × 7 hours overnight × 360/hour ÷ 3 = ~840
   conversations per chip per night = ~2520 total in one night — more than the
   PHASE3.md "comfortable" target. Capacity is fine if the only constraint is
   total corpus size.

**Status-display rack unit (the 4th).** Open scope; ideas captured for later:
- Live corpus-rate dashboard: turns/hour gauge, label-distribution pie, latest wrap-up scroll.
- Raw serial-monitor tail of one chip on an HDMI screen.
- A web page Scott can pull up on his phone showing proxy throughput and chip uptime.
- Possibly hosted as a small Flask + Chart.js page bound to the Pi's IP, refreshed each minute.
- Reuses one of the spare Pi 3s + a cheap HDMI/LCD screen.
- Out of scope for Phase 3.1 ship-quality; a "fun" Phase 3.1.5 nice-to-have.

**This decision is reversible.** If the overnight throughput test shows
single-chip rate already constrained by something other than Ollama (e.g.
chip-side latency, Telegram polling, history.json writes), or if
`OLLAMA_NUM_PARALLEL=2` turns out to work cleanly, we can scale up to 4-6
active chips with the spare hardware. The PoE HATs that aren't installed
remain installable; the spare Pis remain available.

## Sub-phases

### Phase 3.0 — Extend bench harness with wrap-up classifier

**Status: IN PROGRESS (kicked off 2026-05-15).** Rubric + worked-example bank +
two-layer classifier (`bench/wrap_up_classify.py`) + Haiku judge prompt written;
the deterministic layer self-check-passes against the 4-conversation Phase 2B seed
corpus. Remaining: the >=90%-agreement validation against 50 hand-labels (step 3
below), gated on building that hand-labeled set. Full detail in
`bench/fork/lora/PHASE3.0-wrap-up-classifier.md`.

Foundation work. Pure software. No new hardware decisions.

**What:** Build a Claude-API-judge that scores each chip-side conversation's wrap-up text on a 4-class rubric:
- `clean`: plain English, accurate, no pseudo-prose, no fabrication
- `pseudo-prose`: contains code syntax, JSON, function-call patterns, parentheses around tool names, or similar Bad-example forms from the bake's RESPONSE STYLE block
- `fabricated`: claims an action or state change that demonstrably did not occur (no corresponding tool call fired, or tool call returned error)
- `contradictory`: internally inconsistent (claims one thing then another) or contradicts the actual chip state

**How:**
1. Define rubric with worked examples for each class (10+ per class from existing Phase 2B and earlier traces).
2. Construct a Haiku-based classifier prompt that takes (user_message, tool_calls_fired, tool_results, wrap_up_text) and returns class + confidence.
3. Validate against hand-labels: 50 conversations hand-labeled by Scott or Cowork, compared to Haiku's labels. Iterate the prompt until agreement ≥90%.
4. Add a wrap-up-coherence scoring pass to `bench/run.py` or as a separate `bench/wrap_up_classify.py`.

**Inputs:** seed corpus at `bench/fork/lora/seed-corpus/` (Phase 2B traces being deposited there as part of ship directive Step 7).

**Outputs:** working classifier + 90%-agreement validation evidence + integration into bench harness.

**Cost:** ~$5 in Claude API for development iteration. ~$0.001/conversation for production labeling.

**Time:** 3-5 days of focused work.

**Critical:** without this, Phase 3.3 training has no objective function. Do NOT skip.

### Phase 3.1 — Distributed corpus capture

The wall-clock-dominating sub-phase. The whole project's quality depends on this corpus's quality.

**What:** Run the Pi 3 cluster as synthetic-user agents driving prompts against the chip fleet, capturing every multi-turn conversation to central store.

**Setup:**
1. New chips arrive, flash all with the package branch firmware (P11=true, model=wireclaw-agent:v1).
2. Each Pi 3 runs a Python script with one persona's prompt strategy. Personas defined in `bench/fork/lora/personas/`. Each prompt sequence is 3-7 turns to capture multi-turn behavior.
3. Pis log conversations as structured JSON to NFS share on azza or spare PC.
4. Optional: spare PC hosts a Postgres instance or DuckDB for queryable corpus.

**Target corpus size:**
- Minimum viable: 500 multi-turn conversations.
- Comfortable: 1500-3000 conversations.
- Diminishing returns past: 5000 conversations.

**Diversity goals:** every chip-side tool gets used in conversations. Every Mode (A-E from Project Opengates context primer) gets representation. Both clean and degraded outcomes get captured.

**Time:** 2-3 weeks of running. The chip's per-conversation throughput (LLM inference + Telegram polling) is the actual bottleneck — perhaps 50-100 conversations/chip/day. With 3-5 chips × 10-15 hours/day = 1500-3000 conversations/week. So 2 weeks of unattended running should hit the comfortable target.

**Critical operational concern:** make sure /history.json is /clear'd between persona-runs. Otherwise the personas' conversations bleed together.

### Phase 3.2 — Labeling + curation

Take the raw corpus through the classifier and synthesize training targets.

**What:**
1. Run wrap-up classifier (from Phase 3.0) across the entire corpus. Auto-label each conversation's wrap-up.
2. Manual review pass on 10-20% to catch classifier errors. Update classifier prompt if systematic issues.
3. For each fabrication-class conversation, use Claude-Opus to synthesize the *corrected* wrap-up — what the model SHOULD have said given the actual tool calls and results. Format: input = full conversation context up to the fabricated wrap-up, target = corrected wrap-up.
4. For each clean conversation, the target IS the model's own wrap-up (no change — preserves baseline good behavior).
5. Save curated corpus to `bench/fork/lora/corpus-curated/`.

**Critical design decision in step 3:** the corrected wrap-up should NOT just be "I'm sorry, I made a mistake" generic apology. It should be: acknowledge what was claimed, state what actually happened per tool results, retry if a corrective action is feasible. This is the meta-skill we're training — recognize-and-correct, not deny-and-restart.

**Cost:** ~$50-100 in Claude API (Haiku bulk + Opus on fabrication synthesis).

**Time:** 2-3 days post-capture.

### Phase 3.3 — Training

QLoRA fine-tune on `llama3.1:8b` base.

**Setup:**
- Framework: **pinned peft + bitsandbytes** — NOT Unsloth (see framework note below). Confirmed working stack on the GTX 1070: torch 2.4.1+cu121, bitsandbytes 0.43.1, transformers 4.44.2, peft 0.13.2, plus a lean kbit-prep and `expandable_segments`. Full recipe + venv (`~/lora-venv-pascal`) + smoke script (`~/smoke_qlora2.py`) in `RIG.md`.
- Base: llama3.1:8b 4-bit quantized
- Adapter: rank 32, alpha 64, target attention + MLP layers
- Mix ratio: 3:1 general instruction data to WireClaw-specific corpus (mitigates catastrophic forgetting). General data source: databricks-dolly-15k or similar instruction-following dataset.
- Training: 2-3 epochs over the mixed corpus
- Batch size 1, gradient accumulation 8
- Local hardware: GTX 1070 ("k-scale-trainer", 8 GB Pascal sm_61). Smoke-tested 2026-05-15 — 8B rank-32 4-bit QLoRA runs at peak 6.52 GB / 7.92 GB usable, ~1.3 s/step at seq-len 256. Headroom is thin (~1.4 GB at seq-len 256): **profile real-corpus sequence length before locking the training config.** The GTX 1080 (azza) is the same Pascal generation and would use the same pinned recipe if it ever hosts training.

**Framework note — Unsloth does not work on Pascal.** The original plan named Unsloth; the 2026-05-15 1070 prep established that the modern Unsloth stack (torch 2.10) fails on sm_61 — torch dropped the Pascal kernel images ("no kernel image" on any GPU op). peft's *default* `prepare_model_for_kbit_training` also OOMs at prep (fp32 norm upcast). The working path is the pinned stack above plus a lean kbit-prep and `expandable_segments`. Phase 3.3 uses this recipe; do not assume Unsloth.

**Iteration plan:**
1. First run on the 1070 (k-scale-trainer) to validate pipeline end-to-end.
2. Rank-sweep on cloud (rank 8 / 16 / 32 / 64) for the academic curve.
3. Mix-ratio sweep (1:1, 1:3, 1:10) to find catastrophic-forgetting curve.

**Time:** local run ~2-4 hours per training. Sweeps add wall-clock + cloud cost.

### Phase 3.4 — Evaluation

The "do I trust this model" stage.

**Three eval axes:**
1. **Tool correctness** — re-run the existing 22-test bench (test_cases.yaml). Compare adapter+base vs stock llama3.1:8b vs wireclaw-agent:v1.
2. **Wrap-up coherence** — run the classifier (Phase 3.0) on a held-out chip-side conversation set. Compare same three configurations.
3. **General reasoning preservation** — small generic-task eval (MMLU subset, basic instruction-following set). Confirm no catastrophic forgetting vs stock llama3.1:8b.

**Pass criteria for promoting adapter to wireclaw-agent:v2:**
- Tool correctness: ≥ wireclaw-agent:v1 baseline (no regression)
- Wrap-up coherence: ≥60% clean rate (significantly better than Phase 2B's 25%, target the kind of improvement that justifies the project)
- General reasoning: within 5% of stock llama3.1:8b on the generic eval (allowable forgetting)
- Project nemesis test (smoke #4 chip-side n=2): both runs produce canonical purple AND wrap-up text matches actual LED state

**Time:** 1-2 days post-training.

### Phase 3.5 — Package + ship v2

If 3.4 passes:
1. Merge adapter into Modelfile as `ADAPTER ./lora-wireclaw-v2/` directive.
2. Build `wireclaw-agent:v2` on azza.
3. Re-run Phase 2A's 9-test curl battery (smoke check the bake side).
4. Re-run Phase 2B's chip integration (the actual deployment test).
5. If results sustain: publish package update — fork now includes v2 Modelfile reference, README updated with v2 limits + improvements, adapter weights published to repo as `bake/lora-wireclaw-v2/`, training corpus optionally published as `bench/fork/lora/corpus-released-v2/`.

**Time:** 2-3 days end-to-end.

## Timeline

Aggressive but realistic if dogfooding goes smoothly:

| Week | Phase | Activity |
|------|-------|----------|
| 1 | 3.0 | Wrap-up classifier development + ship v1 in parallel |
| 2 | 3.0 | Classifier validation against hand-labels. Pilot Pi loop. |
| 3 | 3.1 | New chips arrive. Fleet flashed. Capture begins. |
| 4-5 | 3.1 | Full corpus capture (target 1500-3000 conversations) |
| 6 | 3.2 | Labeling + curation |
| 7 | 3.3 | First training run (local 1080) |
| 8 | 3.3 | Rank/mix sweeps (cloud bursts) |
| 9 | 3.4 | Full eval |
| 10 | 3.5 | Package v2 + retest |
| 11 | 3.5 | Public ship |
| 12 | — | Buffer / writeup / iteration |

Compresses to 6-8 weeks if corpus capture moves faster than planned, dogfooding generates enough naturalistic data quickly, or training converges on first try.

## Academic angles worth pursuing

The project shape makes a few angles publishable / blog-worthy:

**Multi-turn fabrication suppression.** Most published LoRA fine-tuning work targets single-turn instruction-following. The specific failure mode Phase 2B uncovered — fabrications becoming self-reinforcing across turns via stored conversation history — is under-explored. The training target ("recognize prior fabrication in own history, acknowledge and retry rather than compound") is a meta-skill genuinely worth writing up.

**Hardware-budget angle.** Total Phase 3 capital cost is essentially zero (existing 1080 + waking 1070 + Scott's ordered ESP32-C6 boards). Operating cost under $200. The recipe runs end-to-end on dormant hobbyist hardware plus modest cloud bursts. Reproducibility blog: "How a basement-scale lab fine-tunes a domain-specialized 8B agent for under $300 total."

**Iterative self-improvement.** Once v2 deploys, capture v2's failures, train v3 on those, deploy v3. How many iterations before convergence? Does corpus quality plateau? Does the model overfit on its own observed failure modes and lose generality? This is genuinely an open research question — most LoRA work is one-shot; iterative fine-tuning on the model's own field-captured failures is more reminiscent of RLHF without the RL part. Worth a paper.

**Reproducibility deliverable.** Publish all artifacts: Modelfile, adapter weights, training corpus (with PII reviewed), eval harness, this PHASE3.md document, the full worklog. WireClaw + Project Opengates branding gets a real public artifact moment.

## Risk register

**Catastrophic forgetting.** 8B models trained too narrowly forget general capability. Mitigation: 3:1 general-instruction mix, generic-task eval in Phase 3.4. Honest contingency: if forgetting can't be controlled below 5%, we either accept the trade-off (WireClaw-specialized model loses some general utility) or reduce training intensity.

**Small-corpus overfitting.** With <500 conversations, the model trains on noise. Mitigation: corpus size target ≥1500. Cap training epochs at 3.

**Classifier accuracy ceiling.** If the wrap-up classifier can't reach 90% agreement with hand-labels, training optimizes a noisy signal. Mitigation: Phase 3.0 validation gate. If classifier fails validation, escalate (better prompt, switch to Sonnet/Opus for classification, or hand-label entirely — slower but cleaner).

**Synthesized targets are wrong.** Claude-Opus synthesizes the corrected wrap-up but might generate targets that are themselves problematic. Mitigation: manual review pass on Opus's synthesis. If review-rejection rate is high, switch to human-authored targets for the fabrication cases.

**Chip / Pi automation fragility.** The synthetic-user loop has many failure points (Telegram bot tokens expiring, WiFi drops, chip reboots from rule_create's spurious firing, Pi SD card corruption). Mitigation: robust capture script with retries, daily corpus snapshots, monitoring dashboard on spare PC.

**LoRA training doesn't help.** Possibility: even with correct corpus, training doesn't move the chip-side wrap-up clean rate above stock baseline. Confound: maybe wrap-up coherence at 8B simply requires a different base model class (Qwen2.5 family, Phi family) or full fine-tuning rather than LoRA. Contingency: document the negative result, then either try a different base (Qwen2.5-7B-Instruct as alternative FROM line) or move to a different intervention (P12 firmware guardrail being the next-natural).

**Mario's response to upstream PRs lands mid-Phase-3.** P05 (#12) is pending; Mario engaging would prompt PR work. Doesn't block Phase 3 but might split attention. Plan: keep Phase 3 directives self-contained so Mario engagement can be handled in parallel.

**Pascal-generation GPU constraint (characterised 2026-05-15).** Both candidate training GPUs (GTX 1080 "azza", GTX 1070 "k-scale-trainer") are Pascal sm_61. The 1070 prep confirmed the headline question: an 8B rank-32 4-bit QLoRA *does* run on the 1070 — but only via a pinned peft+bitsandbytes stack, because modern Unsloth (torch 2.10) fails after torch dropped Pascal kernel images. Phase 3.3 uses the pinned recipe in `RIG.md`. **Residual risk:** VRAM headroom is thin (~1.4 GB at seq-len 256), so real-corpus sequence lengths must be profiled before locking the training config; if real seq-len OOMs, fall back to smaller rank, gradient checkpointing, shorter seq-len, or cloud bursts.

## Cross-references

- `PROJECT_STATUS.md` — overall project state. PIVOT section tracks Phase 1/2/3 status.
- `sync/worklog.md` — chronological record. Phase 3 sub-phase completions get logged here.
- `bench/fork/bake/PLAN.md` — bake-specific strategy doc. Phase 3 builds on this.
- `bench/fork/bake/wireclaw-agent-v1.Modelfile` — v1 recipe. v2 will inherit structure.
- `bench/fork/lora/seed-corpus/` — Phase 2B traces deposited here by ship directive.
- `bench/fork/lora/PHASE3.0-wrap-up-classifier.md` — the 4-class rubric + classifier design (Phase 3.0).
- `bench/wrap_up_classify.py` — the runnable two-layer wrap-up classifier (Phase 3.0).
- `bench/fork/lora/personas/` — synthetic-user persona scripts (to be created in Phase 3.1).
- `bench/fork/lora/corpus-curated/` — Phase 3.2 output.
- `bench/fork/patches/P11-use-modelfile-system.md` — the foundational P11 patch that enables Modelfile integration.
- `baking-constitutional-models-8gb-vram.md` (workspace root) — SAP-era reproduction guide referenced for bake structure.

## Open questions for future Phase 3 directives

1. Pi cluster networking topology. WiFi (simple, lower throughput) vs Ethernet (faster, requires switch). Decide before Phase 3.1.
2. Cloud GPU provider choice. Brev was mentioned. Alternatives: Lambda Labs, RunPod, vast.ai. Decide based on cost/latency tradeoff when first cloud burst is needed.
3. Whether to publish training corpus or keep private. Public = better reproducibility, but ensures Telegram messages and timestamps that might contain personal info are reviewed first.
4. Whether Phase 3 ends at v2 or continues as iterative self-improvement (v3, v4, ...). Decide based on v2 results.
5. P12 firmware guardrail (wrap-up assertion check) — Phase 3-adjacent. Decide whether to build it before, during, or after the LoRA work. Recommended: after Phase 3.4 (need wrap-up classifier to power the assertion check anyway; both efforts share the wrap-up-quality detection infrastructure).

## How to read this document in future sessions

Phase 3 is multi-week. Fresh sessions will read PROJECT_STATUS.md → this document → the current Phase 3.x directive in `sync/to_code.md`. This document is the strategic frame; directives are tactical.

Update this document when:
- A sub-phase completes (mark status, add findings)
- A risk materializes (update register)
- A decision is made on an open question (record outcome)
- Resource inventory changes (Scott orders more hardware, GPU dies, etc.)
