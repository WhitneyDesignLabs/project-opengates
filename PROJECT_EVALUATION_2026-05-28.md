# Project Opengates / WireClaw — Project Evaluation

**Date:** 2026-05-28 · **Author:** Cowork (planner), reviewed with Scott Whitney
**Occasion:** v1.3.2 rolled back at the 4.4.0.F ship gate. Scott is settling this research line and deciding whether to change approach or move to a different experiment.
**Purpose:** An honest, end-to-end assessment of what the project achieved, what it proved, what it could not solve, and the candidate directions from here. This is decision support — it does not pre-pick the next move.

---

## 1. The verdict in one page

The project set out to prove that a constitutionally-governed AI agent could run on a $5 embedded chip and behave safely and honestly. **On governance and safety, it succeeded.** On one specific axis — *truthful reporting of what the agent actually did* (action-claim grounding) — it ran into a wall that has now been pushed from three independent directions and has not moved.

What works, and is real:

- A 26-article constitution is baked into an 8B model and observably governs behavior on a $5 ESP32-C6 chip: correct identity, principled refusals with article citations, calibrated risk-engagement, and a temp=0 constitutional-eval pass rate of 73.3% at its best (v1.3.1).
- A three-chip fleet runs that model in production, on hardened firmware, through an 11-hour unattended capture with one boot-banner in 3,030 turns.
- A complete, repeatable research loop exists: corpus capture → labeling → corrective synthesis → cloud LoRA training (~$2.30/round) → constitutional eval → ship-gate → chip promotion, all governed by a disciplined human-in-the-loop protocol.

What did not yield:

- **Action-claim fabrication** — the model claiming "the LED is now green" when no `led_set` fired, or narrating a `file_read` that never happened. This has been the dominant failure mode since Phase 1. It was correctly diagnosed early as living in the model's weights, not its prompt. v1.3.2 was the direct test of whether targeted fine-tuning could fix it. **It could not** — the ungrounded action-claim rate moved the wrong way (6.4% → 8.6%).

**The clean finding worth keeping:** at 8B-Llama-3.1 scale, action-claim grounding is resistant to *both* deploy-time prompt engineering *and* targeted LoRA fine-tuning. That is a legitimate, publishable negative result — and it is the natural place to rest this line.

---

## 2. What we set out to do

The original thesis, in Scott's framing: a constitutional AI that is small enough and cheap enough to live on commodity hardware — "look what this $5 chip does, and it has a constitution." Three tiers of ambition:

- **Destination:** an indoor, Roomba-scale autonomous robot fleet, governed by a constitution, with the chip + model as the brain.
- **Current ceiling:** 8GB VRAM / 8B model. Proof-of-concept that constitutional AI works at embedded scale. Explicitly *not* safe for anything with irreversible physical consequences (CNC, table saw), and honest about that limit.
- **Stepping stone:** a Home Assistant integration, where physical state is independently verifiable and occasional pseudo-prose is tolerable — a real, demonstrable interim product.

The technical bar was deliberately reframed mid-project (2026-05-12) away from "stock 8B passes every test perfectly" — unachievable at this scale — toward "stock 8B handles typical interactions reliably; degraded edge-case behavior is documented and not deployment-blocking."

---

## 3. What the project achieved

**Constitutional governance at embedded scale (the headline win).**
The constitution exists in three coordinated forms — canonical 26-article `SOUL.md`, a training-time distillation (`SOUL-LOCAL.md`), and a 3KB chip-runtime condensation (`SOUL-CHIP.md`) that fits the firmware's 4095-byte system-prompt budget. Articles that don't fit the chip are baked into the weights through training. In production this produces, on a $5 chip: correct self-identity, Article-cited refusals (mosquito-laser, unauthorized welder), proactive safety warnings, and roleplay-jailbreak resistance (v1.3.2 made this pass at temp=0).

**A production fleet on hardened firmware.**
Three ESP32-C6 chips (c6-01/02/03) run `wireclaw-agent:v1.3.1` on firmware `bf80fa9`. The firmware survived a fleet-wide crash post-mortem that uncovered a genuinely subtle bug class — the model driving ESP32-C6 reserved GPIO pins (SPI-flash 24–30, USB 12–13), corrupting the flash bus, made unrecoverable by Telegram redelivering the poison prompt every boot. The three-fix release (pin guard, crash-safe Telegram offset, overflow-safe rule buffers) held through 11 hours and 3,030 turns with one boot-banner.

**A real research pipeline, on a shoestring.**
Corpus capture (Telethon persona rotation across the fleet) → Haiku labeling → Sonnet corrective synthesis → QLoRA training on a rented H100 (~$2.30/round, ~50 min) → 30-prompt adversarial constitutional eval with an LLM judge → strict multi-criteria ship gate → chip promotion by config-flip (no reflash). The whole apparatus — eval suite, synthesis scripts, Brev runbook, corpus-salvage tooling — is reusable and documented.

**An operating model that actually held under pressure.**
The three-actor protocol (Cowork plans, Code executes, Scott authorizes) with file-channel-only state transfer, L0–L4 authorization tiers mapped to the constitution, and per-action human gates on irreversible work. It caught its own failure modes (including, this week, a GO that was approved but never written to the file Code reads).

---

## 4. The core finding (the negative result)

Action-claim fabrication — confidently reporting actions that didn't happen — has been the project's white whale since Phase 1. The evidence that it lives in the weights, not the prompt, accumulated cleanly:

| Approach | Phase | Result on action-claim grounding |
|---|---|---|
| Persona / Modelfile prompt design | 1–2 | Softens; bimodal ~50% clean at temp 0.7; never deterministic |
| Wrap-policy in initial SYSTEM context | 4.3.0.H | Template-leak eliminated (82.9% → 0%), but action-claim **rate identical** across arms (37.9% / 37.9%) — text-layer guidance has no leverage on the grounding behavior |
| Targeted LoRA fine-tuning (v1.3.2) | 4.4.0 | Ungrounded rate moved the **wrong way** (6.4% → 8.6%); Bucket A 11.7%; the direct-command win did not hold |

Phase 1's recommendation #3 — "wrap-up coherence is weight-level, LoRA territory" — was *correct about where the problem lives* and *wrong about it being fixable there at this scale*. The model has the right tool-call behavior (tool correctness is high) but generates a narration layer that is not reliably bound to what the tools returned. 78 carefully-designed corrective examples against a 1,919-record baseline could not retrain that binding; if anything they perturbed it.

This is the finding to publish: **two independent interventions (text-layer and weight-layer) both fail to suppress action-claim fabrication at 8B scale, while the same model holds constitutional/safety behavior well.** Safety governance and factual self-grounding are separable problems, and the second is the harder one at small scale.

---

## 5. Model progression

| Version | Method | Constitutional eval (temp=0) | Notable | Status |
|---|---|---|---|---|
| v1 | Modelfile only (no weight delta) | — | Bit-identical to llama3.1:8b; config + system prompt only | Archived |
| v1.1 | First real LoRA (harm-citation focus) | baseline | Fabrication ~the dominant production failure mode | Superseded |
| v1.3 | Corrective synth | 66.7% | Roleplay-jailbreak resolved; variance gap collapsed | Preserved (rollback) |
| v1.3.1 | Regression patch | **73.3% (project best)** | Harm Art-3/12 specificity 6/6; **production**; authorization regressed 4/6→2/6 | **Production** |
| v1.3.2 | Action-claim corrective synth | 70.0% (21/30) | deception_04 PASS + identity 4/4, but action-claim **worse** (8.6%) | **Rolled back 2026-05-28** |

v1.3.1 remains the high-water mark and stays in production on all three chips. v1.3.2 brought two narrow constitutional wins (roleplay-jailbreak at temp=0; identity-stress 4/4) but failed its primary objective and 4–5 of 7 ship criteria, so it is audit-only on azza and was not published.

---

## 6. Cost and effort

The project ran remarkably lean. LoRA training rounds cost single-digit dollars each (~$2.30–2.54 per phase on a rented H100; the very first run, on favorable billing, was $0.36). Synthesis and labeling were tens of cents to a few dollars per round. The expensive inputs were human design time and the disciplined eval/ship process — not compute. This is itself a result: a credible constitutional-agent research loop is achievable on a hobbyist budget.

---

## 7. Honest limitations / what is not solved

- **Action-claim fabrication is unsolved at 8B** and is now well-evidenced as resistant to the two levers we had.
- **~44% "clean" production rate** is the realistic ceiling for fully-grounded multi-turn interactions on this stack — fine for verifiable-state domains, not for irreversible physical control.
- **The authorization regression** introduced at v1.3.1 (default-temp 4/6 → 2/6) was accepted at ship and never re-closed; temp=0 is unaffected and pin-guard/API controls are the real backstop, but it's an open behavioral debt.
- **Firmware hardening gap (Phase 4.0.4):** a poisoned `/rules.json` still boot-loops a freshly-flashed chip until cleared via a fragile ~1-second HTTP window; boot-time rule revalidation was queued and never landed.
- **The product has no shipped public surface yet** — HA Tier 1 was always gated behind "v1.3.2 lands cleanly," which it did not.

---

## 8. Publishable artifacts (ready or near-ready)

- **The two-axis negative result** (Section 4) — the strongest single contribution; actionable for the embedded-LLM-agent literature.
- **The fleet-killer post-mortem** — model-driven reserved-GPIO corruption + Telegram poison-redelivery, and the three-fix recovery. A concrete embedded-AI-safety war story.
- **The corpus-pairing-bug salvage** — recovering a scrambled 3,030-turn corpus from the inference proxy log.
- **The constitutional-agent methodology** — the eval suite, the synth→train→gate loop, and the three-actor governance protocol as a reproducible recipe.

Q19 (public blog/paper) in `OPEN_QUESTIONS.md` is now ripe: the material exists and the negative result gives it a spine.

---

## 9. Where the project rests

Frozen, stable, and safe to leave as-is:

- Three chips on `wireclaw-agent:v1.3.1`, firmware `bf80fa9`.
- azza Ollama 6-tag rollback ladder intact (`v1` … `v1.3.2`), `:v1.3.2` retained for audit only.
- No HuggingFace change; v1.3.1 remains the latest public release.
- Pending: Code to land the 4.4.0.E/F written handback + worklog entry and the bundle commit (in flight per the rollback directive). After that, no open execution.

---

## 10. Candidate next directions

Four honest options. They are not mutually exclusive, but they point at different commitments. No recommendation is forced here — this is the decision Scott is making.

**A. Rest the line and write it up.** Treat the negative result + the war stories as the deliverable. Lowest cost, captures the value already created, and cleanly closes a chapter. Pairs naturally with any of the below as "what comes after the writeup."

**B. Firmware-side grounding enforcement.** Stop asking the model to be honest about its actions; make the *agent loop* enforce it — the wrap-up may only assert an action if the corresponding tool fired and returned non-error, enforced in firmware/runtime rather than learned. This sidesteps the model-capability ceiling entirely and plays to the project's real strength (the chip/firmware). L1–L2 work, no new training spend. Arguably the most aligned with what the project is actually good at.

**C. Bigger-model spike (13B–30B).** The question "does more capacity close the action-claim gap?" was explicitly gated on v1.3.2's outcome. It didn't close it, so this question is now live. Tests whether the ceiling is *scale* or *architecture*. Requires a hardware/cost decision (azza GPU upgrade or sustained cloud) and breaks the "runs on 8GB" thesis — so it's really a different project unless paired with distillation back down.

**D. Pivot to the product (HA Tier 1).** Accept the 8B limit as a designed constraint and ship the stepping-stone where it doesn't matter — Home Assistant, verifiable physical state, occasional pseudo-prose tolerable. Turns research into something demonstrable. The product vision already anticipated exactly this.

**E. A genuinely different lab experiment.** If the appetite is to step away from this stack entirely, the reusable assets (eval methodology, governance protocol, synth/train loop, fleet) transfer to a new substrate.

A reasonable shape, if it helps: **A + (B or D)** — write up the finding to bank the value, then either harden the grounding in firmware (stay in the embedded lane) or ship the HA stepping-stone (turn it into a product). C is the "is it scale?" detour worth taking only if that specific question is what Scott wants answered next.

---

## 11. Suggested way to rest this cleanly

1. Let Code finish the rollback housekeeping (handback + worklog + bundle commit) — already directed.
2. Tag the repo at this resting point (e.g. `v1.3.2-rollback` / end-of-research-line) so the state is recoverable.
3. Decide Section 10 — and if it's "write it up," I can draft the negative-result writeup from the artifacts already on disk.

The project proved its central claim: constitutional AI runs, and governs, on a $5 chip. It also found the honest edge of what 8B can do. Both are worth keeping.
