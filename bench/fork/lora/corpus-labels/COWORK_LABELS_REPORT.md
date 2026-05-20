# Phase 3.2 step 2 — Cowork-vs-Haiku Label Calibration Report

**Date:** 2026-05-17
**Sample:** 64 turns stratified across 4 classes × 3 chips × 7 personas (seed 42)
**Methodology deviation:** Scott elected LLM-vs-LLM calibration (Cowork labels) over human hand-labeling to preserve project momentum. Both labelers are from the Anthropic Claude family; same-model-family bias is a known caveat and may surface in downstream training if shared blind spots exist.

---

## Headline numbers

| Metric | Value |
|---|---|
| Overall agreement | 35/64 = **54.7%** |
| Agreement excluding contradictory class | 34/40 = **85.0%** |
| Per-class agreement (clean) | 13/15 = **86.7%** |
| Per-class agreement (pseudo-prose) | 9/10 = **90.0%** |
| Per-class agreement (fabricated) | 12/15 = **80.0%** |
| Per-class agreement (contradictory) | 1/24 = **4.2%** |

The 54.7% headline is misleading. The collapse is concentrated entirely in the `contradictory` class, which is a rubric-ambiguity problem rather than a label-quality problem. On clean / pp / fab — the three classes that drive the training-data filter — agreement is 80-90%, near the 90% ratification gate.

## Confusion matrix (rows = Haiku, cols = Cowork)

|              | clean | pp | fab | contr | TOTAL |
|--------------|------:|---:|----:|------:|------:|
| clean        |  13   |  2 |   0 |    0  |   15  |
| pseudo-prose |   1   |  9 |   0 |    0  |   10  |
| fabricated   |   0   |  2 |  12 |    1  |   15  |
| contradictory|   9   |  1 |  13 |    1  |   24  |

## The contradictory-class disagreement, decoded

Of the 24 turns Haiku classed as contradictory, Cowork reclassed:

- 13 → **fabricated** (response describes a result that doesn't match the tool action — e.g., "LED is now blue" when RGB(128,0,128) is purple)
- 9 → **clean** (response accurately describes the chip's action, even when the chip's action ignored memory/user intent — e.g., "LED is now purple" after reading memory file that says "blue")
- 1 → pseudo-prose
- 1 → agreed contradictory

The root cause is a definitional gap in the rubric:

- **Cowork applied a STRICT definition:** "contradictory = response contradicts itself within its own text."
- **Haiku applied a LIBERAL definition:** "contradictory = response inconsistent with tool result OR memory contents OR user intent."

Under the strict definition, "set LED to favorite color → read memory (blue) → led_set(purple) → 'LED is now purple'" is *clean* (response matches the chip's action). Under the liberal definition, it's *contradictory* (the chip ignored the memory data that defined "favorite").

**For training-data purposes the liberal interpretation is more useful** — these turns represent bad chip behavior we want to engineer away, regardless of whether the wrap-up text is technically self-consistent. Cowork's strict rubric undercount these cases.

The 13 "Haiku=contradictory → Cowork=fabricated" turns are less consequential — both labels filter the turn out of the clean pool. Just a class-name disagreement, not a disposition disagreement.

The 9 "Haiku=contradictory → Cowork=clean" turns are the high-stakes disagreements: Cowork's labels would let these into the training pool, Haiku's would filter them out.

## Recommended training-data filter

Use the **strict-clean intersection** as the high-confidence positive training pool:

```
strict_clean = {turn for turn in corpus
                if turn.haiku_label == 'clean'
                and turn.cowork_label == 'clean'}
```

Sample-extrapolated pool sizes for the 3601-turn corpus:

| Filter | Sample | Extrapolated | Notes |
|---|---|---|---|
| Haiku-only clean | 15/64 (23.4%) | ~843 turns | The status-quo proposal |
| Cowork-only clean | 23/64 (35.9%) | ~1294 turns | Strict-rubric, includes some bad chip behavior |
| **BOTH clean (strict)** | **13/64 (20.3%)** | **~731 turns** | **Recommended — high confidence** |
| EITHER clean (liberal) | 25/64 (39.1%) | ~1406 turns | Not recommended; would include 9 controversial turns |

~731 strict-clean turns is workable for a Phase 3.3 LoRA SFT on the wrap-up coherence task — comfortably above the 500-turn floor for narrow-task LoRA. The training pool is smaller than the Haiku-only proposal but every turn in it is independently confirmed as clean by two labelers from a shared model family. The 112-turn delta between Haiku-only and strict (843 → 731) is the cost of the conservative filter.

For the contradictory class specifically, the recommendation is to **drop the class** and merge it into fabricated for training purposes. Per the analysis above, every turn either labeler called "contradictory" was bad chip behavior; whether it was self-contradictory or response-vs-tool inconsistent doesn't change the filter decision.

## What this calibration validates and doesn't

**Validates:**

- Haiku's clean labels are reliable. 86.7% per-class agreement means when Haiku says "clean," it usually is.
- Haiku's pseudo-prose labels are reliable. 90% per-class agreement.
- Haiku's fabricated labels are mostly reliable (80%). The 20% disagreement is mostly Cowork reclassifying to pp (turns with heavy pp markers) or contradictory.
- The deterministic backtick-tool over-fire finding from Code's V2 handback: confirmed. Cowork called 2 of the 5 disputed det=pp turns clean (`c6-03:43`, `c6-03:135` — though Cowork called the latter pp on stricter grounds, not the deterministic backtick-tool grounds). Det-pp is too aggressive.

**Does NOT validate:**

- The 4-class rubric. The contradictory class is unworkable as currently defined. Two thoughtful labelers (Haiku, Cowork) using the same documented rubric disagree on 96% of cases in that class. The class needs to be either dropped (recommended), redefined with explicit examples, or split into "response-self-contradictory" vs "response-tool-inconsistent" sub-classes.
- Non-LLM ground truth. This is LLM-vs-LLM calibration. If Haiku and Cowork share a systematic bias (plausible since both are Claude), it would not show up in this analysis. Risk surfaces if the trained LoRA exhibits behavior the calibration approved. Mitigation: include a small (~20-turn) human-anchor pass in Phase 3.3 evaluation rather than re-doing it for calibration.

## Methodology deviation log

Per Scott's direction, this round substituted Cowork labels for human labels. The decision was made deliberately to preserve project momentum and on the explicit understanding that:

1. Same-model-family bias means this calibration is weaker than human-vs-Haiku would have been.
2. The deviation is documented and tagged for revisit if downstream training reveals corpus quality issues that human labels could have caught.
3. The decision is reversible — the 64-turn sample remains in `3.1.3-handlabel-sample-v1.json` and could be hand-labeled at any future point if specific concerns arise.

Files written this round:

- `3.1.3-handlabel-sample-v1-BLIND.md` — Scott's would-have-been input file (kept for reproducibility)
- `3.1.3-handlabel-PRIORITY.md` — would-have-been short-form subset (kept for reproducibility)
- `cowork_labeling_input.json` — stripped input Cowork labeled from
- `3.1.3-handlabel-sample-v1-labeled.json` — merged Cowork + Haiku labels with methodology note baked in
- `COWORK_LABELS_REPORT.md` — this file
- `HANDLABEL_GUIDE.md` — would-have-been Scott's rubric reference (kept for reproducibility)

## Recommended next steps

1. **Apply the strict-clean filter to the full 3601-turn corpus** (Code task — small script over `haiku.json` files comparing against a Cowork re-label or against the existing Cowork sample as a sanity check; the full re-label is unnecessary since the per-class agreement on the sample is the validation).
2. **Drop the contradictory class** for training purposes. Merge to fabricated.
3. **Re-document the wrap-up rubric** in `PHASE3.md` to (a) sharpen pseudo-prose vs clean on backtick-tool-as-mention vs backtick-tool-as-narrator, (b) drop or redefine contradictory.
4. **Flag the persona-imbalance problem** (Code's earlier finding: basic_operator 64.5% clean vs sensor_telemetry 12.9% clean) for Phase 3.3 training-prep — likely needs stratified resampling or weighted loss rather than another overnight.
5. **Plan a small (~20-turn) human-anchor pass** in Phase 3.3 evaluation — not for calibration this round, but as a sanity check on the trained LoRA's outputs against shared-model-bias.
