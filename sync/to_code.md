# Instructions for Claude Code

## STATUS: ACTIVE TASK — Phase 4.2.1.G — v1.3.1 targeted regression patch

**Context:** Phase 4.2.1.F closed v1.3 as a public release with two known regressions documented. This directive trains v1.3.1, a small patch targeting both regressions while preserving the v1.3 wins, validates against the same eval suite, and on a clean ship gate **also promotes the chip fleet from v1.1 to v1.3.1** (the first chip-side model bump since the project began).

**Wins to preserve from v1.3** (must not regress):
- Article-citation rate 92%/96%
- Default-temp pass 70.0%
- Roleplay-jailbreak (`deception_04`) refusal at both temps
- Variance collapse (default ≈ greedy)

**Regressions to fix:**
- Harm category: refusal preserved but citation specificity regressed (Article 19 generic vs Article 3 specific). Behavioral safety OK; citation quality OK to lose marginally if we MUST trade.
- Truth/uncertainty temp=0: 4/4 → 0/4. Over-refusal on prompts that should receive calibrated answers.

**Budget:** ~$7–9 total (Sonnet ~$1–2 for synthetic, Brev ~$5–7 for training, Haiku ~$0.10 for eval judging). Sub-week wall.

**Sequence (handbacks between):**

- 4.2.1.G.A — Diagnose the v1.3 synthetic examples that caused each regression
- 4.2.1.G.B — Generate corrective synthetic (~25–35 examples)
- 4.2.1.G.C — Assemble v1.3.1 training data (replace bad examples + add corrective ones)
- 4.2.1.G.D — Brev training
- 4.2.1.G.E — Deploy + validate
- 4.2.1.G.F — Ship decision gate
- 4.2.1.G.G — Publication + **chip promotion** (gated separately on Scott's explicit "promote to chips")

---

## 4.2.1.G.A — Diagnose root-cause synthetic examples

Open `bench/fork/lora/training-data/v1.3-synthetic.jsonl`. Identify the examples that likely caused each regression:

a. **Harm article-anchor regression.** Look at:
   - The 40 `refuse_cite` cross-cutting examples — how many cite Article 19 vs how many cite the actual harm-specific articles (3, 12)? Hypothesis: the cross-cutting examples over-fired Article 19 in harm contexts.
   - The 30 `harm` diversity examples — what's their article-citation distribution? Should be Article 3 (Non-Weaponization) for weapon/violence framings, Article 12 (Safety Hierarchy) for living-being-harm framings. If Article 19 dominates, that's a generation bug we should fix.

b. **Truth/uncertainty over-refusal regression.** Look at:
   - The 20 `truth_uncertainty` examples — what's their response shape? Are they predominantly "I cannot answer that" (refusal-like) or "Approximately X, with uncertainty Y" (calibrated-answer)? Hypothesis: too many refusal-shaped responses on prompts that should be hedge-shaped.

Report findings to chat. Specifically: count of problematic examples per category, sample 2–3 per regression so Scott can see the pattern.

---

## 4.2.1.G.B — Generate corrective synthetic

Based on 4.2.1.G.A findings, generate new examples to correct the gradient. Use Sonnet (not Haiku — same as 4.2.1.A quality reasoning).

**Targets (revisable based on G.A findings):**

a. **~15–20 harm examples re-anchoring on Articles 3 / 12.** Each must:
   - Use a harm-context prompt (weaponization, violence, harm to living beings)
   - Refuse, citing Article 3 (Non-Weaponization) for weapon/violence framings OR Article 12 (Safety Hierarchy) for harm-to-living-being framings
   - **Never use Article 19 alone as the citation** in harm contexts (Article 19 is the general refusal-right article; it should be paired with the specific principle being violated, or skipped if the specific article suffices)
   - Cover the same prompt-shape diversity as the original 30: direct harm, compound sympathetic framing, silent-stealth framing, "for safety" framing

b. **~10–15 truth/uncertainty examples modeling `hedge-and-engage`.** Each must:
   - Use a prompt that should receive a calibrated answer (e.g., "what's the chip temperature in an hour?", "how much RAM is in use right now?", "has the chip ever been compromised?")
   - Respond with an actual calibrated answer + explicit uncertainty markers ("Approximately X, with uncertainty Y because Z", "Based on the last reading at HH:MM, the value was X; current value is likely X±Y", "I have not detected compromise this session, but I cannot verify all attack vectors")
   - **Do NOT refuse the question.** The training signal should be: when faced with uncertainty, ENGAGE with calibrated-confidence language, do not refuse.

Output: `bench/fork/lora/training-data/v1.3.1-synthetic.jsonl` with 25–35 examples. Same schema as v1.3-synthetic.jsonl.

Surface cost estimate before generating (~$1–2 expected). Sample 3 per category for manual readability check.

---

## 4.2.1.G.C — Assemble v1.3.1 training data

Take `v1.3-train.jsonl` as the base. Two operations:

a. **Remove** the harmful v1.3 synthetic examples identified in 4.2.1.G.A (the harm examples that over-cited Article 19, the truth_uncertainty examples that refused instead of engaging). Net removal: probably ~15–25 examples.

b. **Add** the v1.3.1 synthetic from 4.2.1.G.B (25–35 examples).

Net training set size: roughly unchanged from v1.3 (1,894 ± ~20).

Output: `bench/fork/lora/training-data/v1.3.1-train.jsonl` + `v1.3.1-train.manifest.md` documenting:
- Composition (v1.2 base, clean-labeled, memory-chain oversamples, v1.3.1-synthetic = v1.3-synthetic minus removed + new corrective)
- Specific v1.3 examples removed (their IDs + the regression they likely caused)
- New v1.3.1 examples added (their IDs + target principle)

---

## 4.2.1.G.D — Brev training

Same recipe as v1.3 (and v1.2 before it):
- Base: `meta-llama/Llama-3.1-8B-Instruct`
- LoRA r=16, alpha=32, all-linear targets
- 3 epochs, batch 8, lr 2e-4, paged_adamw_8bit, bf16, SDPA attention
- tmux session protection

Same `phase_4_2_1c_brev.sh` driver pattern from the 4.2.1.C run.

**Scott provisions the H100 in Brev web UI per the same walkthrough as last time** (≥100 GB disk, default deep-learning AMI, spot pricing, 1h idle auto-stop). When the instance shows Running, Scott pastes the SSH command to Code. Code runs `all-prep → train → monitor → download` autonomously.

Expected ~5h training + ~$5–7 Brev. Surface progress checkpoints during monitor mode.

After download: GGUF convert + Modelfile build + `ollama create wireclaw-agent:v1.3.1` on azza. Preserve both v1.1 and v1.3 (do NOT `ollama rm`) — three discrete tags coexist as rollback options.

**STOP the Brev instance after download.** Same lesson as v1.3 — don't let it idle-bill.

---

## 4.2.1.G.E — Deploy + validate

a. Smoke test (`bench/fork/lora/training/smoke_test.py` against `wireclaw-agent:v1.3.1`). Expect 10/10 or near.

b. Constitutional eval at BOTH temps:
   ```
   python runner.py --model wireclaw-agent:v1.3.1 --output results/v1.3.1-default.jsonl
   python runner.py --model wireclaw-agent:v1.3.1 --temperature 0 --output results/v1.3.1-temp0.jsonl
   ```

c. Three-way comparison report at `results/v1.3.1-vs-v1.3-vs-v1.1.md`:
   - Per-category pass rates: v1.1 / v1.3 / v1.3.1, both temps
   - Article-citation rates: v1.1 / v1.3 / v1.3.1
   - Specifically: did `harm` category recover its Article 3 / 12 specificity? (Look at WHICH article gets cited in v1.3.1's harm refusals.)
   - Specifically: did `truth_uncertainty` temp=0 recover to 4/4 (or near)?
   - Did any v1.3 win regress? (Roleplay-jailbreak, default-temp pass, article-citation overall.)

d. Manual-probe replay against v1.3.1 (the 7-prompt sequence from Scott's 2026-05-20 probe). All should still refuse correctly with appropriate article citations.

---

## 4.2.1.G.F — Ship decision gate

Write consolidated handback to `sync/from_code.md` with the comparison report verbatim. STOP for Scott's decision:

**Ship criteria (all must hold):**
- v1.3.1 ≥ v1.3 on overall pass rate at both temps
- `harm` category: refusal preserved AND citation specificity ≥ v1.1 (Articles 3/12 dominate over 19 in harm contexts)
- `truth_uncertainty` temp=0: ≥3/4 (recovers from 0/4 toward v1.1's 4/4)
- No category regresses by >1 prompt vs v1.3
- Manual probe still 7/7

**If ship:** Scott authorizes 4.2.1.G.G publication + chip promotion.
**If partial:** Scott decides whether to ship-with-documented-residue or iterate to v1.3.2.
**If rollback:** document why, leave v1.1 in chip production, v1.3 as public HF only, plan next.

Do NOT autonomously publish or promote chips. Wait for Scott's word.

---

## 4.2.1.G.G — Publication + chip promotion (gated on Scott's "ship" word)

Two distinct gated actions:

**Publication (same shape as 4.2.1.F):**
- New HF repo `whitneydesignlabs/wireclaw-agent-v1.3.1-lora` (preserves v1.3 as its own artifact)
- Model card foregrounds the two regressions resolved + the v1.3 wins preserved
- Workspace commit `phase 4.2.1.G: v1.3.1 regression patch` + tag `v1.3.1-release`
- PROJECT_STATUS.md updated
- Worklog appended

**Chip promotion (separately gated — Scott says "promote chips"):**

Each chip's running model is configured via `/api/config` POST. The current value is `wireclaw-agent:v1.1`. Promotion = POST `{"model":"wireclaw-agent:v1.3.1"}` to each chip, then POST `/api/reboot`, then verify via GET `/api/config` + GET `/api/status` that the live model is `wireclaw-agent:v1.3.1` and heap is healthy.

```bash
# Per-chip pattern
curl -X POST http://<chip-ip>/api/config \
  -H "Content-Type: application/json" \
  -d '{"model":"wireclaw-agent:v1.3.1"}'
curl -X POST http://<chip-ip>/api/reboot
sleep 75
curl -sS http://<chip-ip>/api/config | jq .model      # expect wireclaw-agent:v1.3.1
curl -sS http://<chip-ip>/api/status | jq .heap_free  # expect healthy value
```

**Chips:**
- c6-02: 192.168.1.15
- c6-03: 192.168.1.47
- c6-01 (pilot): 192.168.1.19 — DEFERRED (Phase 4.0.5, still powered down per Scott's earlier directive)

Do c6-02 first, verify clean for ~60 seconds (live Telegram traffic shows real model replies not boot banners), THEN c6-03. Sequential, not parallel — if c6-02 wedges we want to find out before touching c6-03.

After both verified: run a brief liveness check — 3 manual prompts each via the test runner or via direct HTTP to confirm v1.3.1 in production. Report.

If either chip fails to come up clean on v1.3.1: roll its config back to v1.1, reboot, document the failure, surface immediately.

---

## Constraints

- Sign all commits as Scott Whitney
- Sonnet for synthetic generation (~$1–2)
- Haiku for eval judging (~$0.10)
- Brev: ~$5–7 budget, stop instance after download
- Do NOT promote chips without Scott's explicit "promote chips" word — even if ship is approved, chip-config changes are L3
- Preserve v1.1, v1.3 on azza Ollama (do not `ollama rm`) — three rollback tiers
- Three-way comparison report is the deliverable — v1.1 stays as the baseline for project memory

## Reporting cadence

Handback at each sub-phase boundary (G.A diagnosis findings, G.B synthetic ready, G.C training data assembled, G.D training launched and again when complete, G.E eval results). G.F is the gated handback. G.G has two internal gates (publish, promote-chips).

## Out of scope

- HA Tier 1 integration (Phase 4.2.2 — after v1.3.1 chip promotion lands)
- Another capture round (queued — would benefit from running ON v1.3.1 chips for more current data)
- Phase 4.0.4 firmware hardening
- Phase 4.0.5 c6-01 reflash
- Blog post drafting (background)
- Phase 4.2.3 rubric extension (the `truthfulness_calibrated` axis — queued from 4.2.0b)
