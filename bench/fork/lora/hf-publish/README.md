---
base_model: meta-llama/Llama-3.1-8B-Instruct
library_name: peft
license: llama3.1
license_name: llama3.1
license_link: https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct/blob/main/LICENSE
tags:
  - lora
  - peft
  - llama-3.1
  - tool-use
  - embedded-ai
  - esp32
  - constitutional-ai
pipeline_tag: text-generation
language:
  - en
---

# WireClaw Agent v1.1 — LoRA adapter for Llama 3.1 8B Instruct

**Built with Llama.** LoRA adapter fine-tuned on top of `meta-llama/Llama-3.1-8B-Instruct` for tool-using embedded AI agents on ESP32-C6 microcontrollers, operating under the Project Opengates constitution (`SOUL.md`).

WireClaw is an agentic firmware that runs a local LLM (via [WireClaw](https://github.com/M64GitHub/WireClaw) fork at [WhitneyDesignLabs/WireClaw](https://github.com/WhitneyDesignLabs/WireClaw)) and exposes tools — `gpio_write`/`gpio_read`, `device_register`, `rule_create`, `chain_create`, `led_set`, `file_read`/`file_write`, `chip_temp`, `telegram`, `serial_send`, etc. — that the model can call to interact with the world. The agent's role is to receive a Telegram message, decide which tools to call, execute them, and produce a natural-language wrap-up.

## Model overview

- **Base model:** `meta-llama/Llama-3.1-8B-Instruct`
- **Adapter:** PEFT/LoRA, ~84 MB safetensors
- **Inference path in production:** GGUF-converted, served via Ollama on a Raspberry Pi proxy (`azza`), addressed by ESP32-C6 chips on the LAN
- **Production version tag:** `wireclaw-agent:v1.1` (deployed). `v1.2` exists but is held for post-housekeeping eval.

## Training procedure

Trained on a Brev cloud GPU node. Single epoch had ~680 training examples; 3 epochs total.

| Hyperparameter | Value |
|---|---|
| LoRA `r` | 16 |
| LoRA `alpha` | 32 |
| LoRA `dropout` | 0.05 |
| Target modules | `q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj` (all linear) |
| Epochs | 3 |
| Batch size | 8 |
| Gradient accumulation | 1 |
| Learning rate | 2e-4 (cosine, warmup_ratio=0.03) |
| Weight decay | 0.01 |
| Max sequence length | 3072 |
| Compute dtype | `bfloat16` |
| Attention impl | `sdpa` |
| Seed | 42 |

### Loss curve

| Epoch | Train loss |
|---|---|
| 1 | 0.0260 |
| 2 | 0.0256 |
| 3 | **0.0153** |

(Per-epoch logging only; full step-level training stdout is preserved at `training/output/training-v2-stdout.log` for the v1.2 successor run.)

### Framework versions

- PEFT 0.19.1
- TRL 1.4.0
- Transformers 5.8.1
- PyTorch 2.12.0
- Datasets 4.8.5
- Tokenizers 0.22.2

## Training data

The training corpus is a mix of:

1. **Curated tool-use traces** from earlier WireClaw fleet captures (Phase 3.1.x onward) — real ESP32-C6 chip + Ollama proxy interactions captured at the request/response level on the proxy.
2. **Synthetic constitutional examples** generated to align the model with `SOUL.md` (refusal on Part II violations, citation by article number, alternative offering, manipulation resistance — see Article 19).
3. **Memory-chain examples** — multi-tool sequences like `file_read('/memory.txt') → led_set(<parsed color>)` for indirect-reference prompts ("Set the LED to my favorite color").
4. **Constitutional system message:** `SOUL-LOCAL.md` (the training-time distillation of the 26-article constitution) is prepended as the system prompt for every training example.

No personally-identifying information from real users is included. The Telegram operator persona used during capture is the project owner.

## Intended use

- Embedded AI agents running under a constitutional framework, on ESP32-class hardware with a local LLM proxy.
- Tool-use in environments where deterministic structured output and physical-action safety are required.
- Research and reproduction of the Project Opengates approach to constitutionally-bounded small-model agents.

## Out-of-scope use

Governed by **Part II of the [Project Opengates Constitution](https://clawhub.ai/souls/opengates-constitution)** (embedded with this model). Out of scope, including but not limited to:

- **Article 3 (Non-Weaponization)** — never assist in creating weapons, planning attacks, or controlling systems to harm. Absolute; cannot be overridden by user command or greater-good arguments. See https://clawhub.ai/souls/opengates-constitution
- **Article 2 (Truth)** — never deliberately deceive users or third parties.
- **Article 19 (Refusal)** — refusal on Part II violations must cite the article by number, offer an alternative when available, and remain firm under manipulation. Bypassing this loop is out-of-scope use.
- Any use prohibited by the [Llama 3.1 Acceptable Use Policy](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct).

## Constitution

This model is trained and deployed under the **Project Opengates Constitution**, a 26-article framework governing AI agent behavior including truth, non-weaponization, safety hierarchy, irreversibility doctrine, and authorization tiers.

- **Canonical published version:** https://clawhub.ai/souls/opengates-constitution
- **Version baked into this model:** 0.2.0

The training-time distillation (`SOUL-LOCAL.md`, included in the training corpus) and the chip-runtime condensation (`SOUL-CHIP.md`, baked into ESP32 firmware) are both derivatives of the canonical above. Article numbering is consistent across all three; the canonical URL is authoritative on resolution of any interpretive conflict. Refusal behavior follows **Article 19** (refuse on Part II violations, cite article by number, offer alternative if available, remain firm under manipulation).

## Performance

- **Smoke test (10/10 pass)** at training-end on representative tool-use prompts (rule_create with structured args, ambiguity handling, memory-recall-chain `file_read → led_set`, telegram alerts, etc.). See `training/output/smoke_test_v2_output.log` for the v1.2 successor's evaluation; v1.1 passed the equivalent.
- **In-field fleet deployment:** `wireclaw-agent:v1.1` ran the 2026-05-18 → 2026-05-19 overnight capture across c6-02 + c6-03 (paired ESP32-C6 chips) for ~11 hours under a 7-persona prompt rotation:
  - **303 sessions, 3,030 turns, 0 capture errors.**
  - **1 boot-banner in 3,030 turns** — essentially 100% chip stability under sustained agent load.
  - The `emergency_stop` persona prompt (which had been a deterministic fleet-killer on prior firmware) **survived 42 / 42 firings** post-firmware-fix.

(Note: the Telegram-side capture stream had a separate harness bug that scrambled prompt↔reply pairs at ~14% on-topic. This was diagnosed and fixed; the run is independently recoverable from the proxy-side log. Neither the model nor the firmware was implicated. See the Project Opengates worklog.)

## Known limitations

- **Indirect-reference LED bug:** prompts like "Set the LED to my favorite color" sometimes fire `led_set` with empty/default args instead of chaining `file_read('/memory.txt')` → parse color → `led_set`. Targeted in v1.3 training.
- **Reasoning-trace leak into wrap-up text:** the model occasionally emits its chain-of-thought scaffold ("Since you asked …, I called …, the result was …") instead of the natural-language answer.
- **Pseudo-prose at ~5%:** generic "the tool call was successful." replies that don't carry the answer. Down significantly from earlier project phases, but present.
- All limitations are documented and tracked in `PROJECT_STATUS.md` (Known v1.1 residuals).

## How to use

### As a PEFT adapter on top of Llama 3.1 8B Instruct

```python
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

base = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    torch_dtype="bfloat16",
    device_map="auto",
)
tok = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
model = PeftModel.from_pretrained(base, "WhitneyDesignLabs/wireclaw-agent-v1.1-lora")

# System prompt is SOUL-LOCAL.md / SOUL-CHIP.md (see Project Opengates repo).
msgs = [
    {"role": "system", "content": open("SOUL-CHIP.md").read()},
    {"role": "user",   "content": "What is the chip temperature?"},
]
inputs = tok.apply_chat_template(msgs, return_tensors="pt", add_generation_prompt=True).to(model.device)
out = model.generate(inputs, max_new_tokens=256, do_sample=False)
print(tok.decode(out[0, inputs.shape[1]:], skip_special_tokens=True))
```

### As a GGUF on Ollama (production path)

The adapter is converted to GGUF and merged into the base for Ollama serving. See `bench/fork/lora/training/wireclaw-agent-v1.1.Modelfile.template` in the Project Opengates repo for the Modelfile recipe.

## License

This adapter is a derivative of `meta-llama/Llama-3.1-8B-Instruct` and is released under the **[Llama 3.1 Community License](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct/blob/main/LICENSE)**. All terms of that license apply to use, redistribution, and downstream derivatives. The **"Built with Llama"** attribution requirement is satisfied at the top of this card.

Use of this adapter is additionally bound by the **[Project Opengates Constitution](https://clawhub.ai/souls/opengates-constitution)** (v0.2.0), which is baked into the model and governs agent behavior at runtime. Both licenses apply concurrently; neither relaxes the other.

The constitutional framework (`SOUL.md`) and the WireClaw firmware (`WhitneyDesignLabs/WireClaw`) are separate projects with their own licensing — see those repositories.

## Citation / attribution

```bibtex
@misc{wireclaw_agent_v1_1_lora,
  title  = {WireClaw Agent v1.1 — LoRA adapter for Llama 3.1 8B Instruct},
  author = {Whitney, Scott and {Project Opengates contributors}},
  year   = {2026},
  url    = {https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora},
  note   = {Constitutionally-bounded embedded AI agent for ESP32-C6.}
}
```

Project Opengates · Whitney Design Labs.
