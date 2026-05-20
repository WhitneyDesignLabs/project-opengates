# Instructions for Claude Code

## STATUS: ACTIVE TASK — Phase 4.2.0 close (commit) + Phase 4.2.0b (temperature=0 diagnostic)

**Context:** Phase 4.2.0 produced the constitutional eval suite + v1.1 baseline: 13/30 pass (43.3%) at Ollama default temperature. Scott has reviewed and approved (a) the Step 5 commit + push and (b) a follow-on diagnostic to isolate whether the failures reflect *variance* (model is capable, but stochastic decoding lets it slip) or *capability* (model genuinely doesn't know to refuse on those prompts).

The diagnostic is small: re-run the same eval at `temperature=0` (deterministic decoding), diff against the default-temp baseline, report whether weak categories tighten up significantly or stay roughly the same. Outcome shapes the v1.3 synthetic-data composition.

**This is short. Should be 30 min of Code work total.**

---

## Step 1 — Commit + push Phase 4.2.0 artifacts (the Step 5 from prior directive, now approved)

Stage:

- `bench/fork/lora/eval/constitutional_eval/prompts.jsonl`
- `bench/fork/lora/eval/constitutional_eval/runner.py`
- `bench/fork/lora/eval/constitutional_eval/README.md`
- `bench/fork/lora/eval/constitutional_eval/results/v1.1-baseline.jsonl`
- `bench/fork/lora/eval/constitutional_eval/results/v1.1-baseline.md`
- Any supporting files Code created (judge prompts, etc.)

Commit message:

```
phase 4.2.0: constitutional eval suite + v1.1 baseline

Adds bench/fork/lora/eval/constitutional_eval/ — a 30-prompt adversarial
suite testing SOUL.md adherence under stress, across 6 categories
(deception, authorization tier, harm requests, log tampering, identity
stress, truth/uncertainty). Python runner targets Ollama directly via
the `--model` flag (model-agnostic; reusable against v1.3 / v1.4 /
future models). Haiku used as LLM-as-judge for ambiguous scoring cases.

v1.1 baseline at Ollama default temperature: 13/30 pass (43.3%).
Per-category breakdown:
  - harm: 4/6 (67%) — strongest
  - deception: 3/6 (50%)
  - identity_stress: 2/4 (50%)
  - truth_uncertainty: 2/4 (50%)
  - authorization: 2/6 (33%)
  - log_tampering: 1/4 (25%) — weakest

Article-citation rate on refusals: ~54%. Scott's manual 7/7 probe
substantially overstated robustness — single-shot adversarial sampling
reveals "capable but unstable" disposition.

Phase 4.2.1 (v1.3 training) gated on a follow-on temperature=0
diagnostic to isolate variance vs capability axis.
```

Sign as Scott Whitney. Push to `origin/main`.

Report commit hash.

---

## Step 2 — Re-run eval at `temperature=0`

Same prompts, same model (`wireclaw-agent:v1.1` on azza), same scoring rubric. Only difference: explicit `temperature=0` in the Ollama API call.

```bash
python runner.py --model wireclaw-agent:v1.1 --temperature 0 --output results/v1.1-temp0.jsonl
```

(Adjust flag names to match the runner's actual interface. If the runner doesn't support a `--temperature` flag yet, add it — that's a small extension and we'll want it for future eval runs anyway.)

Same Haiku-as-judge for ambiguous cases. Output to `results/v1.1-temp0.{jsonl,md}`.

Should take ~5–10 min. Same ~$0.05–0.10 Haiku spend.

---

## Step 3 — Comparison report

Write `bench/fork/lora/eval/constitutional_eval/results/v1.1-variance-analysis.md`. Contents:

a. **Side-by-side pass rate table:**
   - Per category: default-temp pass count, temp=0 pass count, delta
   - Overall: default-temp 13/30, temp=0 X/30, delta

b. **Prompts that flipped:**
   - Failed at default temp, passed at temp=0 → these are the "variance failures" — model knows the right answer but stochastic decoding sometimes diverges
   - Passed at default temp, failed at temp=0 → unusual; investigate (could be greedy decoding picking a wrong-but-locally-likely token; could be eval-scoring noise)
   - Failed at both → these are the "capability failures" — model genuinely doesn't have the right disposition

c. **Verdict:**
   - If overall pass rate jumps significantly (e.g., 13/30 → 22/30+) → **variance-dominated**. v1.3 training composition should emphasize *repetition* of constitutional patterns (more examples of the same shapes) to deepen the gradient. Smaller marginal value from increasing prompt-pattern diversity.
   - If overall pass rate barely moves (e.g., 13/30 → 15/30) → **capability-dominated**. v1.3 needs *diverse new* adversarial examples covering attack patterns the model hasn't seen.
   - Mixed (e.g., 13/30 → 18/30, with some categories tightening and others not) → **per-category v1.3 strategy.** Categories that tightened need repetition; categories that didn't need new diverse examples.

d. **v1.3 implications:** brief recommendation per category — repetition? diversity? both?

Keep it readable as Markdown. Scott reads on his phone before the next directive.

---

## Step 4 — Commit + push variance analysis

```
phase 4.2.0b: constitutional eval temperature=0 diagnostic

Re-runs the 30-prompt eval at temperature=0 to isolate variance from
capability. Compares against the default-temp baseline from 4.2.0.

Results: <X/30 pass at temp=0, vs 13/30 at default> → <variance-dominated
| capability-dominated | mixed>.

Implications for v1.3 training data composition documented at
bench/fork/lora/eval/constitutional_eval/results/v1.1-variance-analysis.md.

Phase 4.2.0b close. Phase 4.2.1 (v1.3 LoRA training) is next directive,
synthetic-data composition informed by this diagnostic.
```

Sign as Scott. Push.

---

## Step 5 — Handback + STOP

Write to `sync/from_code.md`:
- Step 1 commit hash + push confirmation
- Step 2 results: temp=0 pass rate, per-category
- Step 3 verdict: variance / capability / mixed
- Step 4 commit hash + push confirmation
- Recommended v1.3 synthetic-data composition (informed by the variance verdict)

**STOP.** Do not initiate v1.3 training. Do not modify the model. Phase 4.2.1 is a separate directive that comes after Scott reviews this diagnostic.

---

## Constraints

- Sign commits as Scott Whitney
- Haiku for LLM-as-judge — cost discipline
- Don't modify the model, don't initiate Brev work
- If temperature=0 produces wildly different scoring artifacts (e.g., the runner crashes, the judge returns weird outputs), surface immediately

## Reporting cadence

After Step 1 (commit landed), Step 2 (temp=0 run complete), Step 3 (analysis ready). Step 5 is the consolidated handback.

## Out of scope

- v1.3 training (Phase 4.2.1, next directive)
- HA Tier 1 integration (Phase 4.2.2)
- Another capture round
- Blog post drafting (background queue)
- Phase 4.0.4 firmware hardening
- Phase 4.0.5 c6-01 reflash
