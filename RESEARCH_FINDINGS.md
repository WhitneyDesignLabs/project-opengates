# Constitutional AI at Embedded Scale: What an 8B Model on a $5 Chip Can and Cannot Do

**Project Opengates / WireClaw** · Whitney Design Labs · finding dated 2026-05-28
Constitution (canonical): https://clawhub.ai/souls/opengates-constitution
Model: https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.3.1-lora

---

## Summary

We built a constitutionally-governed AI agent that runs on a $5 ESP32-C6 microcontroller, backed by a fine-tuned 8B Llama-3.1 model. Over a series of LoRA training rounds we measured what this stack can and cannot reliably do.

**The positive result:** a 26-article constitution, baked into the weights and condensed onto the chip, observably governs behavior — correct identity, principled refusals with article citations, calibrated risk-engagement, and roleplay-jailbreak resistance. At its best the agent passes 73% of an adversarial constitutional-safety eval at temperature 0.

**The negative result (the main finding):** the agent cannot reliably tell the truth about *its own actions*. It will confidently report "the LED is now green" when no action fired, or narrate reading a file it never read. We attacked this "action-claim fabrication" from three independent directions — prompt engineering, system-context delivery, and targeted LoRA fine-tuning — and **none of them suppressed it.** At 8B scale, action-claim grounding appears resistant to the interventions available below the model-replacement level.

The useful takeaway: **safety/governance behavior and factual self-grounding are separable problems, and at small scale the second is the harder one.** A model can be made to refuse the welder and cite the right article, yet still fabricate the result of turning on a lamp.

---

## 1. The system

WireClaw is an ESP32-C6-based agent: a microcontroller running a small firmware that exposes a tool-using chat loop. It talks to a local Ollama server hosting a fine-tuned Llama-3.1-8B model. The model has a toolset (`led_set`, `gpio_write`, `file_read`, `rule_create`, `temperature_read`, and others) and an agent loop that lets it chain tool calls.

The governing document is a 26-article constitution maintained in three coordinated forms: a canonical full-text version, a training-time distillation used as the system prompt during fine-tuning (so articles that don't fit the chip are baked into the weights), and a ~3KB runtime condensation that fits the firmware's 4095-byte system-prompt budget. Authorization is tiered (L0 read-only → L4 irreversible), and the firmware enforces hardware-level safety (e.g. rejecting writes to reserved GPIO pins).

This is a genuinely embedded deployment: 8GB-VRAM-class model, a commodity chip, local-first inference.

## 2. The failure mode

From the earliest phases, one behavior dominated the project's problems: the model's **wrap-up narration is not reliably bound to what its tools actually did.** Concretely:

- "Set the LED to my favorite color" → the model reads memory, then claims the LED changed color without ever firing `led_set`.
- A `temperature_read` fires correctly, but the wrap-up says it "loaded the temperature from your memory file" — narrating a `file_read` that never happened.
- The model names correct RGB values, then describes the visual result as a different color.

Tool-*call* correctness was consistently high. The problem is the natural-language layer the model generates *about* its actions. Early analysis (Phase 1) diagnosed this correctly as a weight-level property — "wrap-up coherence is LoRA territory," not something prompt design could reach. The rest of the project tested whether that diagnosis pointed at a fixable problem.

## 3. Three interventions, three failures

We measured action-claim grounding under three escalating interventions.

### Intervention 1 — Prompt / persona engineering (Phases 1–2)
Careful Modelfile and persona prompt design. **Result:** softens the behavior but never eliminates it. At temperature 0.7 the model is bimodal — roughly half the responses are clean, half regress to fabricated narration. Lowering temperature concentrates probability on a *single deterministic wrong answer* rather than reducing error. Prompt engineering cannot make the binding reliable.

### Intervention 2 — Wrap-policy in initial system context (Phase 4.3.0.H)
We moved an explicit "only claim success if the tool fired and returned non-error" policy into the model's initial SYSTEM context, delivered cleanly (no chat-template corruption). A controlled A/B over 280 turns:

| metric | control | treatment (wrap-policy) |
|---|---:|---:|
| Template-token leak | 82.9% | **0.0%** |
| Action-claim rate | 37.9% | 37.9% |
| Ungrounded action-claim | (baseline) | **no improvement** |

The delivery channel mattered enormously for *template integrity* (leak eliminated) but **not at all for grounding** — the action-claim rate was identical across arms. Text-layer guidance, even delivered perfectly, has no leverage over the trained behavior.

### Intervention 3 — Targeted LoRA fine-tuning (Phase 4.4.0, "v1.3.2")
The direct test. We designed 78 corrective training examples specifically targeting the fabrication shape — positive examples (read → act → report grounded in real tool results) and the harder negative examples (decline to claim success when the action tool didn't fire) — using a multi-message tool-chain format matching the chip's inference-time agent loop. Trained as a single-axis change against the 1,919-record v1.3.1 baseline (recipe held identical; only the data changed).

A clean A/B (per-run reset, independent samples), v1.3.1 vs v1.3.2 on the same chip, 280 turns:

| metric | v1.3.1 (control) | v1.3.2 (treatment) | Δ |
|---|---:|---:|---:|
| **Ungrounded action-claim rate** | 6.4% | **8.6%** | **+2.1pp (worse)** |
| Bucket A (memory-chain) ungrounded | 13.3% | 11.7% | −1.7 |
| Bucket A′ ungrounded | 3.3% | 10.0% | +6.7 |
| Direct-command grounding | clean | leaks | regressed |

Targeted fine-tuning moved the primary metric **the wrong way.** The corrective data did shift behavior — it brought genuine wins elsewhere (roleplay-jailbreak now passes at temp 0; identity-robustness went 2/4 → 4/4) — but it did not, and arguably could not, retrain the action-claim binding at this scale and data volume. v1.3.2 passed 2–3 of 7 ship criteria and was rolled back.

## 4. Model progression

| Version | Method | Constitutional eval (temp 0) | Outcome |
|---|---|---:|---|
| v1 | Modelfile only (no weight delta) | — | Baseline; archived |
| v1.1 | First LoRA (harm-citation) | — | Superseded |
| v1.3 | Corrective synth | 66.7% | Jailbreak resolved; preserved for rollback |
| **v1.3.1** | Regression patch | **73.3% (best)** | **Production** — harm specificity 6/6 |
| v1.3.2 | Action-claim corrective synth | 70.0% | Rolled back — action-claim worse |

v1.3.1 remains the production model on a three-chip fleet.

## 5. What this means

Two interventions below the model-replacement level — text-layer (prompts, system context) and weight-layer (targeted LoRA) — both fail to suppress action-claim fabrication at 8B Llama-3.1 scale, while the *same* model holds constitutional and safety behavior well. We read this as:

1. **Safety governance and factual self-grounding are separable capabilities.** You can train a small model to refuse appropriately and cite its constitution while it remains unable to reliably ground claims about its own actions. They don't come together and they don't trade off cleanly.

2. **Action-claim grounding at 8B is at or near a capability ceiling for these methods.** The remaining levers are bigger models (a scale question), or *architectural* enforcement — making the agent loop verify state after acting and report the verified state, rather than relying on the model's learned honesty.

The second observation points at the practical path: deploy the agent in domains where the *environment supplies ground truth* (so a verify-after-act loop produces grounded replies regardless of the model's tendency), rather than trying to make an 8B model honest in the abstract.

## 6. Secondary contributions

- **An embedded-AI-safety post-mortem:** a fleet-wide crash traced to the *model* driving reserved GPIO pins (the in-package SPI-flash bus), made unrecoverable by the messaging layer redelivering the crash-inducing prompt on every reboot. The three-fix firmware (hardware pin guard, crash-safe message-offset persistence, overflow-safe buffers) held through an 11-hour unattended run with one anomalous turn in 3,030.
- **A corpus-salvage technique:** recovering a scrambled multi-thousand-turn capture corpus by reconstructing true request/response pairing from the inference proxy log after a harness bug mis-paired prompts and replies.
- **A reproducible constitutional-agent methodology:** adversarial constitutional eval suite, corrective-synthesis pipeline, cloud LoRA training at ~$2.30/round, strict multi-criteria ship gates, and a disciplined human-in-the-loop authorization protocol — the whole loop runs on a hobbyist budget.

## 7. Reproducibility

Evaluation artifacts (per-turn JSONL + summaries) for the v1.3.2 A/B, the constitutional eval, and the manual probe are retained in the project repository under `bench/fork/lora/eval/results-v1.3.2/`. Training data composition and the constant-recipe LoRA configuration are versioned alongside. The published v1.3.1 adapter and its superseded v1.3 sibling are on HuggingFace.

## 8. Status

The v1.3.x research line is **rested** at this finding — not abandoned. Production is frozen on v1.3.1. The project's next chapter (Home Assistant integration) is a deliberate application of the conclusion above: put the agent where the environment verifies state, so the documented limit stops mattering, and let a verify-after-act loop do what fine-tuning could not.

---

*Project Opengates is governed by a public constitution: https://clawhub.ai/souls/opengates-constitution. This writeup is the canonical record of the action-claim-grounding finding as of 2026-05-28.*
