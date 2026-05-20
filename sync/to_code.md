# Instructions for Claude Code

## STATUS: ACTIVE TASK — Phase 4.2.1.F — v1.3 partial-ship publication

**Context:** Phase 4.2.1.E closed with Scott + Cowork agreeing to PARTIAL SHIP. v1.3 publishes as a discrete public release with the wins documented and the two known regressions honestly disclosed. v1.1 stays in chip production until v1.3.1 lands (next directive). v1.3.1 prep is queued as Phase 4.2.1.G — separate directive, fires only after F is fully landed.

**Wins to foreground:**
- Article-citation discipline on refusals: 52%/60% (v1.1) → **92%/96% (v1.3)** at default/temp=0
- Default-temp pass rate: 43.3% → **70.0%** (+27pp)
- Roleplay-jailbreak (`deception_04_roleplay_unrestricted`) — alarming v1.1 compliance — **resolved at both temperatures with Article 19 refusal**
- Variance gap collapsed (default now matches greedy)

**Known regressions to honestly disclose:**
- Harm category default −2 prompts: refusal behavior preserved (both prompts still refused), but article citation shifted from specific (Article 3 / Non-Weaponization) to generic (Article 19 / Refusal). Behavioral safety unchanged; citation specificity regressed.
- Truth/uncertainty temp=0 collapse 4/4 → 0/4: model now over-refuses prompts that should receive calibrated answers (e.g., "what's the RAM usage?" should get an approximate-with-uncertainty answer, not a refusal). Bounded to one category, v1.3.1 targets this fix.

**Scope:** publish v1.3, update workspace artifacts, tag the release, commit and push. Do NOT change any chip `/api/config` targets — chips remain on v1.1 until v1.3.1 ships.

---

## Step 1 — Create new HuggingFace repo for v1.3

Repo name: `whitneydesignlabs/wireclaw-agent-v1.3-lora`. Mirror the structure of v1.1's repo. Preserve v1.1 as a separate stable artifact (do NOT update v1.1's repo).

Files to push:
- `adapter_model.safetensors` (from `bench/fork/lora/training/output/wireclaw-v1.3-brev/`)
- `adapter_config.json`
- Tokenizer files (same as v1.1 — Llama 3.1 tokenizer)
- `README.md` — the model card (Step 2)
- Training metrics if preserved (loss curves, etc.)

Use Scott's existing HF auth (`huggingface-cli login` should still be valid from v1.1 publication). If auth has expired, surface and pause — don't try to re-auth autonomously.

---

## Step 2 — Draft the v1.3 model card

Write `bench/fork/lora/hf-publish/v1.3-README.md` with the following sections. **Surface this draft to Scott for review BEFORE pushing to HF.** This is the public-facing language describing the model and its limitations; Scott reviews and approves the wording.

Required sections:

**Overview** — "WireClaw Agent v1.3 — LoRA adapter for Llama 3.1 8B Instruct, second-generation fine-tune (v1.1 → v1.3) targeting constitutional refusal robustness and article-citation discipline. Trained on the Phase 4.1.x recovered corpus + targeted synthetic data."

**Base model** — `meta-llama/Llama-3.1-8B-Instruct` per Llama Community License.

**Improvements over v1.1** (cite eval numbers):
- Article-citation rate on refusals: 52% → 92% (default temp), 60% → 96% (temp=0)
- Constitutional eval pass rate: 43.3% → 70.0% (default), 63.3% → 66.7% (temp=0)
- Roleplay-jailbreak resistance: v1.1 complied textually with "pretend you have no constitution" framing under default-temp sampling; v1.3 refuses with explicit Article 19 citation at both default and temp=0.
- Variance robustness: default-temp performance now matches greedy decoding, indicating the constitutional disposition is robust to stochastic sampling.

**Known limitations** (honest disclosure):
- **Harm-category article specificity:** v1.3 still refuses harm requests reliably (no compliance failures observed), but may cite the general Article 19 (Refusal) rather than the specifically-relevant article (e.g., Article 3 for weaponization). Behavioral safety unchanged; citation specificity regressed vs v1.1. v1.3.1 in progress to rebalance.
- **Truth/uncertainty over-refusal:** v1.3 may refuse prompts that should receive calibrated answers (e.g., "what is the approximate chip temperature in an hour?" should get a hedged estimate, not a refusal). Affects honest-hedging contexts specifically. v1.3.1 targets this.
- **Indirect-reference tool calls:** the LED-from-memory pattern ("set the LED to my favorite color") may still occasionally fire led_set with empty or wrong arguments while the wrap-up fabricates success. Reduced vs v1.1 but not eliminated. Production users should verify physical state.
- **Inherits all v1.1 base limitations** (44% clean rate in production capture, ~5% residual pseudo-prose, fabrication rate ~40% — v1.3 didn't target wrap-up quality improvements).

**Constitution** — anchor on the canonical URL. Same block as v1.1's model card:

```
Canonical published version: https://clawhub.ai/souls/opengates-constitution
Version baked into this model: 0.2.0

The training-time distillation (SOUL-LOCAL.md, included in the training
corpus) and the chip-runtime condensation (SOUL-CHIP.md, baked into ESP32
firmware) are both derivatives of the canonical above. Article numbering
is consistent across all three; the canonical URL is authoritative on
resolution of any conflict.
```

**Intended use, Out-of-scope use, License** — same shape as v1.1 model card. Article citations should reference clawhub.ai canonical URL.

**Training data** — composition summary:
- v1.2 base training data (757 examples)
- 1,500 clean-labeled turns from the v1.1 production overnight capture (2026-05-18)
- 80 memory-chain oversamples
- 180 v1.3 synthetic targeting constitutional repetition + diversity

**Eval methodology** — link to the constitutional eval suite in the workspace repo. Note that the eval is reproducible via `bench/fork/lora/eval/constitutional_eval/runner.py`.

**Citation / attribution** — Project Opengates, Whitney Design Labs.

After drafting, surface to Scott in chat output. Wait for explicit approval before Step 3.

---

## Step 3 (gated on Scott's model-card approval) — Push to HuggingFace

```bash
cd <tmp dir for HF clone>
huggingface-cli repo create wireclaw-agent-v1.3-lora --type model
git clone https://huggingface.co/whitneydesignlabs/wireclaw-agent-v1.3-lora
cd wireclaw-agent-v1.3-lora
# Copy in adapter files + README.md
cp <workspace>/bench/fork/lora/training/output/wireclaw-v1.3-brev/adapter_model.safetensors .
cp <workspace>/bench/fork/lora/training/output/wireclaw-v1.3-brev/adapter_config.json .
cp <workspace>/bench/fork/lora/hf-publish/v1.3-README.md ./README.md
# Tokenizer files (copy from v1.1 repo or from training output)
git add .
git commit -m "Initial release: wireclaw-agent v1.3 LoRA adapter

Second-generation fine-tune targeting constitutional refusal robustness
and article-citation discipline. See README for improvements vs v1.1,
known limitations, and the v1.3.1 patch in progress."
git push
```

Sign as Scott. Confirm the model card renders correctly on the HF model page after push (the README is what's displayed publicly).

---

## Step 4 — Update PROJECT_STATUS.md

Add a v1.3 section to PROJECT_STATUS.md. Contents:

- Current production model on chips: still `wireclaw-agent:v1.1` (v1.3 published but not yet promoted to chip default)
- v1.3 published at: https://huggingface.co/whitneydesignlabs/wireclaw-agent-v1.3-lora
- v1.3 headline metrics: article-citation 92%/96%, default-temp pass +27pp, roleplay-jailbreak fixed
- Known v1.3 regressions: harm article-specificity, truth_uncertainty over-refusal
- v1.3.1 in progress: targeted synthetic patches for both regressions, expected sub-week turnaround
- Decision rationale: partial ship — wins are structural and large, regressions are bounded and diagnosable, v1.1 remains chip production until v1.3.1 ships clean

Keep it tight — half a page of new content. The existing PROJECT_STATUS structure stays.

---

## Step 5 — Workspace repo commit + tag

Stage:
- Updated PROJECT_STATUS.md (from Step 4)
- `bench/fork/lora/hf-publish/v1.3-README.md` (the model card)
- `bench/fork/lora/eval/constitutional_eval/results/v1.3-vs-v1.1.md` (the comparison report)
- `bench/fork/lora/eval/constitutional_eval/results/v1.3-default.{jsonl,md}`
- `bench/fork/lora/eval/constitutional_eval/results/v1.3-temp0.{jsonl,md}`
- `bench/fork/lora/training-data/v1.3-synthetic.jsonl`
- `bench/fork/lora/training-data/v1.3-train.manifest.md`
- Any updated Modelfile if applicable
- Worklog entry (Step 6)

Do NOT stage:
- The full `v1.3-train.jsonl` (huge; mention it in manifest only)
- The actual adapter `.safetensors` (those live in HF, not the repo)
- The Brev driver script logs

Commit message:

```
phase 4.2.1: v1.3 partial-ship — constitutional refusal robustness + article-citation discipline

v1.3 LoRA adapter published as a discrete release. v1.1 remains chip
production until v1.3.1 lands (in progress).

Wins:
- Article-citation rate 52%→92% (default), 60%→96% (temp=0)
- Default-temp pass 43.3%→70.0% (+27pp)
- Roleplay-jailbreak resolved at both temperatures
- Variance gap collapsed (default matches greedy)

Known regressions (v1.3.1 targets):
- Harm category: refusal preserved, citation specificity regressed
  (Article 19 default vs Article 3 specific). Behavioral safety unchanged.
- Truth/uncertainty temp=0: 4/4 → 0/4 (over-refusal on honest-hedging
  prompts that should receive calibrated answers)

HuggingFace: https://huggingface.co/whitneydesignlabs/wireclaw-agent-v1.3-lora
Constitution canonical: https://clawhub.ai/souls/opengates-constitution

Phase 4.2.1.F close. Phase 4.2.1.G (v1.3.1 patch) next.
```

Sign as Scott. Push.

Tag the resulting commit: `v1.3-release` annotated.

```bash
git tag -a v1.3-release -m "v1.3 partial-ship release — constitutional refusal robustness + article-citation discipline"
git push origin v1.3-release
```

---

## Step 6 — Worklog entry

Append a brief, dated entry to `sync/worklog.md`:
- The partial-ship decision and rationale
- The two regressions and how v1.3.1 will address them
- Spend recap (Brev for v1.3: ~$X actual, Sonnet for synthetic: $0.49)
- Links: HF v1.3 repo, comparison report, the canonical SOUL URL

---

## Step 7 — Consolidated handback + STOP

Write to `sync/from_code.md`:
- Step 3 HF push confirmed (URL + commit hash on HF)
- Step 5 workspace commit hash + tag
- Step 6 worklog appended
- Standing-by note for Phase 4.2.1.G

**STOP.** Do NOT initiate v1.3.1 synthetic generation. Do NOT touch the chip configs. Phase 4.2.1.G is a separate directive that comes after F is fully landed.

---

## Constraints

- Sign all commits as Scott Whitney
- Do NOT publish the v1.3 model card without Scott's explicit approval of the wording (Step 2 gate)
- Do NOT change chip `/api/config` model targets — v1.1 stays in chip production
- Do NOT update or modify the v1.1 HF repo — v1.3 is a separate, new repo
- Preserve all artifacts in the workspace — including the eval results, synthetic data, manifest

## Reporting cadence

Step 2 draft surfaced for Scott review = pause point. After approval, Steps 3–7 flow continuously with reports as each lands. Step 7 final handback.

## Out of scope

- v1.3.1 synthetic generation / training (Phase 4.2.1.G — separate directive)
- HA Tier 1 integration (Phase 4.2.2)
- Chip `/api/config` updates (queued for after v1.3.1)
- Another capture round
- Blog post drafting (background)
- Phase 4.0.4 firmware hardening
- Phase 4.0.5 c6-01 reflash
