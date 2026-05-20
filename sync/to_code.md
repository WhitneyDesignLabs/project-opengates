# Instructions for Claude Code

## STATUS: ACTIVE TASK — Phase 4.1.4a — Haiku-label v1.1 corpus + 3.1.3 comparison + fork docs merge

**Context:** Phase 4.1.3 closed clean. The 3,030-turn salvaged-and-repaired v1.1 corpus from the 2026-05-18 overnight has never been labeled. Without labels, every downstream decision (v1.3 training targets, "good enough" threshold, capture-more vs ship-now) is speculative. This directive produces the measurements Cowork + Scott need to do the big-picture goal/metrics review.

**Out of scope:** v1.3 training, capture round, c6-01 reflash, Phase 4.0.4 firmware hardening. Those come after the big-picture review.

---

## Step 1 — Merge `docs-canonical-soul-url` → `wdl-v1` on the fork (cleanup)

Small carryover from 4.1.3. Scott has approved the merge so the canonical-URL anchor appears on the fork's default-branch README view (verification surface 8).

```bash
cd /mnt/c/Users/homet/Documents/WireClaw-fork
git fetch origin
git checkout wdl-v1
git merge --no-ff origin/docs-canonical-soul-url -m "Merge branch 'docs-canonical-soul-url' into wdl-v1

Adds the canonical Project Opengates Constitution URL anchor to
README-WhitneyDesignLabs.md so the binding constitutional text is
discoverable from the fork's default branch."
git push origin wdl-v1
```

Sign the merge commit as Scott Whitney. Report success.

---

## Step 2 — Locate corpus + existing 3.1.3 baseline labels

a. **v1.1 corpus to label:** `bench/fork/lora/corpus/v1.1-overnight-2026-05-18.REPAIRED.jsonl` (3,030 turns post-salvage). Confirm file present + line count.

b. **3.1.3 baseline labels (if they exist):** look in `bench/fork/lora/corpus-labels/` for any Haiku-labeled 3.1.3 output. Per worklog/task history, the 3.1.3 corpus was Haiku-labeled in an earlier round (Phase 3.2). Find the labeled JSONL or JSON output (NOT the hand-label `.md` files — those are a smaller stratified sample). Report:
   - Path to the labeled 3.1.3 corpus
   - Total label count
   - Label taxonomy used (should be the same one we're about to apply)
   - Per-label counts (the distribution we'll compare against)

c. **Labeling tool:** the existing `bench/wrap_up_classify.py` (or whatever the canonical name is in this repo) was used for 3.1.3. Locate it, confirm it runs, confirm it uses Claude Haiku (not Sonnet/Opus — cost discipline). If the API key / env var setup needs anything, surface it before spending.

Report findings before proceeding to Step 3.

---

## Step 3 — Haiku-label the v1.1 corpus

a. **Cost check before spending:** estimate the API cost for labeling 3,030 turns. Prior runs were ~$2–3 per 250 turns extrapolating to ~$25–35 for this corpus. Surface the estimate before firing.

b. **Run the labeler.** Use the same taxonomy that was applied to 3.1.3 (whatever clean / pseudo-prose / fabricated / JSON-leak / etc. categories the existing classifier uses). Output to:
   `bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.labeled.jsonl`

c. **v1.3-target failure modes — flag these specifically.** Even if the base taxonomy doesn't have explicit categories for them, the classifier should add boolean flags or notes for:
   - **led_indirect_reference_bug** — turn pattern: user says "make it my favorite color" / "set the LED to my color" / similar indirect reference; chip's wrap-up CLAIMS success but the led_set tool call was either absent, had empty args, or had wrong args. This is the pilot-p10 / live-probe-4:42-PM failure mode.
   - **reasoning_trace_leak** — wrap-up text exposes internal monologue ("I should have responded in plain English," "let me try a different approach instead," "the tool call was wrong so I'll..."). George Washington response from the live probe was an example.
   - **memory_chain_correct** — the chained file_read → use-value-in-next-tool-call pattern (positive signal worth tracking, not a failure).

   If the existing classifier doesn't support extra flags, extend it minimally — these three are the v1.3 training targets and we need their rates.

d. Report progress as labeling runs (rate-limited Anthropic API typically takes 30–60 min wall for ~3K turns). If it stalls or errors, surface immediately.

---

## Step 4 — Generate analysis report

After labeling completes, compute and write a structured report to `bench/fork/lora/corpus-labels/v1.1-vs-3.1.3-comparison.md`. Contents:

a. **v1.1 corpus stats:**
   - Total turns
   - Per-persona breakdown (turns + label distribution per persona, all 7 personas)
   - Per-chip breakdown (c6-02 vs c6-03, label distribution per chip)
   - Per-label totals + percentages

b. **3.1.3 baseline stats:** same shape, side-by-side for direct comparison.

c. **v1.1 vs 3.1.3 deltas:** per label, per persona where overlap exists. Highlight where v1.1 substantially beats 3.1.3 (the wins from LoRA training) and where v1.1 is comparable or worse (potential regression areas).

d. **v1.3-target failure modes:**
   - `led_indirect_reference_bug` rate in v1.1
   - `reasoning_trace_leak` rate in v1.1
   - `memory_chain_correct` rate in v1.1
   - For each: 3 representative example turns (with prompt, expected behavior, actual behavior)

e. **Top 10 failure modes by frequency:** ranked list with one-sentence description + a representative turn.

f. **Sample 20 turns by stratification:** 2–3 examples per label category, raw prompt + reply + label, so Scott can spot-check classifier accuracy.

Keep it readable as a Markdown document — Scott will read this on his phone or on the workstation before the big-picture review.

---

## Step 5 — Consolidated handback + STOP

Write the handback to `sync/from_code.md`:
- Confirm Step 1 fork merge landed (commit hash on `wdl-v1`)
- Confirm corpus labeled (counts, label distribution headline)
- Confirm comparison report at `bench/fork/lora/corpus-labels/v1.1-vs-3.1.3-comparison.md` with brief topline ("v1.1 beats 3.1.3 by X on clean-label rate" or "comparable" or whatever the data shows)
- Confirm spend (actual API cost vs estimate)
- Standing-by note for the big-picture review

**STOP after the handback.** Do NOT initiate v1.3 training, do NOT initiate a new capture, do NOT add synthetic data. The next phase is Cowork + Scott doing the big-picture review using the report as input data.

---

## Reporting cadence

Surface each step's completion as you finish. Step 2 (corpus + 3.1.3 labels located) is the gate before Step 3 spends money — report findings, wait for Scott to say "spend." Step 3 progress updates every ~500 turns labeled so Scott knows it's alive. Step 4 report drop in chat output (or summary if too long). Step 5 final handback.

## Constraints

- Use Claude Haiku for labeling (cost discipline) — not Sonnet/Opus.
- Sign all commits as Scott Whitney.
- Do not modify the v1.1 corpus file itself — labeling is additive (separate labeled JSONL), not destructive.
- If labeling fails partway through, save partial progress, report, and let Scott decide whether to resume or restart.
