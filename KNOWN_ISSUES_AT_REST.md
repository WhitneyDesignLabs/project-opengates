# Known Issues at Rest — 2026-05-28

Companion to `PROJECT_EVALUATION_2026-05-28.md` (what we achieved) and `RESEARCH_FINDINGS.md`
(the public negative-result writeup). This is the **open-debts ledger** as the project enters its
documented resting state at the 4.4.0.F / 4.5.0 curtain call. A future session — Home Assistant
Tier 1 or otherwise — should read this first so it inherits the known problems cleanly instead of
re-discovering them.

Production at rest: three chips on `wireclaw-agent:v1.3.1` + firmware `bf80fa9`; azza 6-tag
rollback ladder intact (`:v1.3.2` audit-only, never promoted, never published to HF). Repo tagged
`v1.3.2-rollback`.

---

## 1. Firmware 4.0.4 gap — poisoned `/rules.json` boot loop

**Severity:** medium (recovery is fragile but known). **Status:** open, deferred.

A freshly-flashed chip with a poisoned/oversized `/rules.json` boot-loops on startup. Recovery
depends on hitting a fragile ~1-second HTTP window after reset to clear/overwrite the rules file
before the next crash. This bit c6-01 during Phase 4.0.5 (revived this way).

- **Queued-but-never-landed fix:** boot-time rule revalidation — the firmware should validate
  `/rules.json` on boot and fall back to a safe default rather than crash-looping on a bad file.
- **Reserved-pin guard** (GPIO 24–30, 12–13) landed in 4.0.3 and is unrelated — that one is closed.
- **Recovery procedure reference:** the ~1s HTTP-window clear; see `SDCARD_PROVISIONING.md` /
  Phase 4.0.5 notes and the worklog entries around c6-01 revival.

## 2. Authorization regression at default temperature

**Severity:** low-medium (mitigated by other backstops). **Status:** accepted at ship, never re-closed.

v1.3.1 default-temperature authorization behavior measured **4/6 → 2/6** vs the prior baseline.
- **temp=0 is unaffected** — the regression is sampling-variance-driven at higher temperature.
- The **pin guard + API-level controls are the actual-harm backstop**, so this was accepted as a
  behavioral (not safety) regression at the v1.3.1 ship gate.
- It was never re-closed because the v1.3.2 effort (which might have addressed priors broadly) was
  rolled back. Carries forward as an open behavioral debt on the production model.

## 3. Action-claim fabrication ceiling — the headline negative result

**Severity:** high (defines the product ceiling). **Status:** characterized, rested. See evaluation.

Action-claim grounding at 8B Llama-3.1 resisted **both** levers tried:
- **(a) deploy-time text-layer prompt engineering** (Phase 4.3.0.H) — template-leak eliminated but
  behavioral grounding not fixed.
- **(b) targeted LoRA fine-tuning of the priors** (Phase 4.4.0 / v1.3.2) — ungrounded action-claim
  rate moved the *wrong* way, 6.4% → 8.6% (target was <4%); rolled back at 2–3 of 7 ship criteria.

Net: ~44%-clean on action-claim grounding, resistant to the available levers. This is the
characterized ceiling, not a bug to be patched on the v1.3.x line. The strategic answer is to design
*around* it (HA Tier 1 supplies external ground truth via verify-after-act) — see
`HA_TIER1_GROUNDWORK.md` and the evaluation. Full pointer: `PROJECT_EVALUATION_2026-05-28.md`.

## 4. v1.3.x carry-forward levers — rested, not lost

These were identified but **not** pursued before the line was rested. Recorded so they aren't
re-derived if anyone revisits the v1.3.x corrective-synth approach:

- **Double bucket-1** in the corrective synth: 3 → 6–8 examples (action-claim grounding bucket was
  under-weighted relative to its difficulty).
- **LED color rebalance:** blue/green were under-represented in the training distribution relative
  to red/amber; rebalancing may reduce an observed color bias.

Neither is queued. Do **not** start v1.3.3 work from these without a fresh directive — the research
line is intentionally at rest.

## 5. Other open residuals a fresh session should know

- **`:v1.3.2` is an audit-only additive tag on azza.** Do not delete it, do not promote any chip to
  it, do not publish it to HuggingFace. It exists purely so the rollback decision is auditable
  against real artifacts.
- **Raw proxy capture dir** `bench/fork/lora/eval/results-v1.3.2/proxy-2026-05-28/` is intentionally
  **gitignored / excluded from commits** per the raw-proxy convention (preserved on azza). The
  analyzed/derived results (`action_claim_ab.{md,jsonl}`, `constitutional_*.{md,jsonl}`,
  `manual_probe.md`) ARE committed.
- **HF project token in `Secrets.txt` is read-scoped** (per BREV_GOTCHAS #16). Any HF card edit
  needs a write token Scott supplies, or Scott applies the edit in the HF web UI. Don't assume write
  access.
- **Many `??` untracked training-data / corpus files** in the working tree are pre-existing and
  intentionally untracked — do not bulk-add them.
