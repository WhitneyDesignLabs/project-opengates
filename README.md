# Project Opengates

**Constitution (canonical):** https://clawhub.ai/souls/opengates-constitution
 · **Firmware:** [WhitneyDesignLabs/WireClaw](https://github.com/WhitneyDesignLabs/WireClaw)
 · **Model:** [WhitneyDesignLabs/wireclaw-agent-v1.1-lora](https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora)

---

Project Opengates is a constitutional AI agent for ESP32-C6 microcontrollers. A LoRA-fine-tuned Llama 3.1 8B Instruct model — trained against a 26-article constitution ([SOUL.md](SOUL.md) / [canonical](https://clawhub.ai/souls/opengates-constitution)) — runs via an Ollama proxy, and is reached by ESP32-C6 chips that execute the [WireClaw firmware](https://github.com/WhitneyDesignLabs/WireClaw). The chips drive GPIO, LEDs, sensors, and Telegram, all under the constitutional refusal-and-authorization framework.

## Current state (v1.1 milestone)

- **Model:** `wireclaw-agent:v1.1` deployed on the production Ollama proxy. v1.2 trained but held for post-housekeeping eval.
- **Firmware:** [`WireClaw@bf80fa9`](https://github.com/WhitneyDesignLabs/WireClaw/releases/tag/firmware-v0.4.1) — three-fix release covering pin guard for ESP32-C6 reserved pins, crash-safe Telegram offset persistence, `rulesSave` OOB write. Validated under 11-hour sustained load: `emergency_stop` prompt survived 42/42 firings, 1 boot-banner in 3,030 captured turns.
- **Fleet:** c6-02 + c6-03 production; c6-01 deferred (Phase 4.0.5).
- **Capture pipeline:** Telethon-driven persona rotation; harness pairing bug discovered + fixed (Phase 4.1.1); corpus salvage from the azza Ollama proxy log is the canonical recovery path.

## Where things live

| | |
|---|---|
| [`SOUL.md`](SOUL.md) | Constitution mirror (26 articles). Canonical is the URL above. |
| [`PROJECT_STATUS.md`](PROJECT_STATUS.md) | Detailed project state — phase history, queued work, known residuals. |
| [`CLAUDE.md`](CLAUDE.md) | Agent-to-agent operational protocol (three-actor distinction, WSL routing, L0–L4 authorization, recurring failure modes). |
| [`bench/fork/lora/`](bench/fork/lora/) | LoRA training pipeline, persona definitions, capture harness. |
| [`bench/fork/lora/training-data/constitution/`](bench/fork/lora/training-data/constitution/) | `SOUL-LOCAL.md` (training-time distillation) and `SOUL-CHIP.md` (chip-runtime condensation, 4095-byte budget). |
| [`bench/fork/lora/hf-publish/`](bench/fork/lora/hf-publish/) | HuggingFace model card source. |
| [`bench/fork/lora/corpus/quarantine/`](bench/fork/lora/corpus/quarantine/) | Scrambled v1.1 overnight corpus + bug-documentation README (the salvage source-material is on azza). |
| [`sync/`](sync/) | File-channel communication between Cowork (planner) and Code (executor) — `to_code.md`, `from_code.md`, `worklog.md`. |
| [`sdcard-images/`](sdcard-images/) | Phase scripts: capture helpers, salvage drivers, deploy scripts. |

## Built with Llama

The agent model is a LoRA derivative of [meta-llama/Llama-3.1-8B-Instruct](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct), released under the [Llama 3.1 Community License](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct/blob/main/LICENSE) and bound additionally by the [Project Opengates Constitution](https://clawhub.ai/souls/opengates-constitution) at runtime.

Project Opengates · Whitney Design Labs.
