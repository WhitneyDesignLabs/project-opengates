# WireClaw / ESP32-C6 — Project Status

**Last updated:** 2026-05-19 midday (Phase 4.1.2 housekeeping — workspace publication + HF model release prep)

## Current state pointer (read this first if you are a fresh session)

**Constitution (canonical):** https://clawhub.ai/souls/opengates-constitution (v0.2.0) — every project artifact links here; treat it as authoritative on any interpretive question.

**Model:** Chip-production is still `wireclaw-agent:v1.1`, deployed on azza (Ollama proxy on `:11435`). **`v1.3` shipped as a partial release on 2026-05-20** — published to [`whitneydesignlabs/wireclaw-agent-v1.3-lora`](https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.3-lora) and live on azza for evaluation, but **not yet promoted to chip default** — chips remain on v1.1 until `v1.3.1` lands. `v1.2` exists from earlier Brev work; held for archival.

**v1.3 release (Phase 4.2.1, partial-ship):**
- HF: https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.3-lora
- Constitutional eval (n=30 adversarial prompts): default-temp pass 43.3% → **70.0%** (+27pp); article-citation rate on refusals 52% → **92%** (default), 60% → **96%** (temp=0).
- Roleplay-jailbreak (v1.1's most concerning default-temp failure) **resolved at both temperatures** with Article 19 citation.
- Variance gap collapsed (default ≈ greedy decoding).
- **Known regressions targeted by v1.3.1:** harm-category article-specificity (refusal preserved, citation shifted from Article 3 → 19 on 2 prompts); truth/uncertainty over-refusal (4/4 → 0/4 at temp=0 — model now refuses prompts that should get calibrated honest hedging).
- Decision: partial ship because wins are structural and large; regressions are bounded and diagnosable. v1.1 remains chip production until v1.3.1 ships clean.
- v1.3.1 in progress: sub-week turnaround, targeted synthetic patches for both regressions; chips promote on the next clean eval.

**Firmware:** `WireClaw-fork @ wdl-v1`, commit **`bf80fa9`** — the three-fix release: (1) pin guard in `tools.cpp` rejects ESP32-C6 reserved pins (12, 13, 24–30) gracefully across every LLM tool entry; (2) `tgSaveOffset`/`tgLoadOffset` in `main.cpp` persists the Telegram offset to LittleFS *before* processing so a crashed message cannot be redelivered forever; (3) overflow-safe `rulesAppend` + 4096→8192 buffers in `rules.cpp`. All three landed in one commit, validated under 11 h sustained load (1 boot-banner in 3,030 turns).

**Fleet:**
- **c6-02** (`192.168.1.15`, paired with pi02 `.17`) — PRODUCTION. `bf80fa9` firmware, full 7-persona rotation under capture.
- **c6-03** (`192.168.1.47`, paired with pi03 `.44`) — PRODUCTION. `bf80fa9`, same.
- **c6-01 / pilot** — DEFERRED (Phase 4.0.5). Last seen boot-looping on old firmware; Scott powered it down 2026-05-19. Out of training rotation; revisit after broader-fleet hardening.
- **c6-pilot bot (`wdl_c6_pilot_bot`)** — separate Telegram bot, retired. Fleet bots are `wdl_c6_02_bot` and `wdl_c6_03_bot`.

**Workspace:** Lives at `C:\Users\homet\Documents\WireClaw\` on Windows / `/mnt/c/Users/homet/Documents/WireClaw/` in WSL. Project-level protocol artifact at `CLAUDE.md` (three-actor distinction Cowork / Code / Scott, WSL routing rules, L0–L4 authz mapped to SOUL.md Article 15, recurring failure modes consolidated). Constitution at `SOUL.md` (canonical 26 articles); chip-runtime variant at `SOUL-CHIP.md` (fits 4095-byte chip budget); training-time variant at `bench/fork/lora/training-data/constitution/SOUL-LOCAL.md`. State transfer between Cowork and Code is **file-channel only** (`sync/to_code.md`, `sync/from_code.md`, `sync/worklog.md`) — chat is not authoritative.

## Recent phases (4.0.x → 4.1.x)

### Phase 4.0.x — Fleet recovery (2026-05-17 → 2026-05-18)

**The arc:** post-mortem of a fleet-wide overnight crash → diagnostic pivot → three-fix firmware → validation.

- **The original (4.0.1) hypothesis** — `rulesSave()` snprintf-accumulation OOB once rules crossed 4 KB — was real but **secondary**. Built + flashed (4.0.2) but the same crash signature reappeared on c6-02 under live persona load with zero rules loaded.
- **The 4.0.3 pivot** identified the actual fleet-killer: `tool_gpio_write` accepted any pin `0..SOC_GPIO_PIN_COUNT(31)`, but on the ESP32-C6 **GPIO 24–30 are the in-package SPI-flash bus** and **GPIO 12–13 are USB D-/D+**. Personas instructed the model to drive GPIO 25/26/27 → flash bus corruption → `rst:0x8 (TG1_WDT_HPSYS)` watchdog reset. Compounding that, `telegramTick()` set `tgLastUpdateId` in RAM and acked on the *next* poll — chip crashed mid-`chatWithLLM()` before that poll → Telegram redelivered the poison prompt every boot → **unrecoverable crash loop**.
- **Three fixes (one commit, `bf80fa9`):** pin guard at every LLM pin-entry point; crash-safe `tgSaveOffset`/`tgLoadOffset` persisting BEFORE processing; the retained `rulesAppend()` OOB fix as defense-in-depth.
- **Validation:** c6-02 + c6-03 reflashed via paired-Pi native USB-JTAG, byte-identical `firmware.bin` sha256 `aa531aa2…`. c6-03 hit a leftover-`/rules.json` boot loop on first power-cycle (poison rule from old firmware) — cleared via the `~1 s HTTP window` `/api/rules/delete {"id":"all"}` hammer recovery. Both stable since.
- **Persona safe-pin remap** (4.0.4a): persona_02 / persona_05 / persona_06 had six edits remapping reserved pins (12, 13, 24–30) to safe range (0–11, 14–23). Intent preserved. Verified zero reserved-pin matches deployed.

### Phase 4.1.x — Capture stabilization + corpus pairing (2026-05-18 → 2026-05-19)

**4.1.0 — First stable overnight.** 2026-05-18 19:11 MST → 2026-05-19 06:02 MST, ~11 h, pi02+pi03 driving c6-02+c6-03 over Telegram via Telethon, full 7-persona rotation, graceful auto-stop via detached `sleep → touch STOP_FLAG` watchdog. **303 sessions, 0 errors, ~100% chip stability.** The remapped persona_06 `emergency_stop` prompt — yesterday's deterministic GPIO-25 fleet-killer — survived **42/42** firings. Only **1** boot-banner in 3,030 captured turns.

**4.1.1 — Harness pairing bug + corpus salvage.** Morning aggregation surfaced that the captured 3,030 turns were **scrambled** at the prompt↔reply level: temperature-prompt → temperature-reply correspondence was only 14.5% (target ~100%), 74.6% scrambled-not-fixed-lag, 16.5% of replies were the literal string `"History cleared"` bleeding across unrelated prompts.
- **Root cause** localized in `bench/fork/lora/persona_runner.py`: `_on_reply` enqueues every Telegram message from the bot into one uncorrelated FIFO; `send_and_await` pops first as "the reply." No `reply_to` correlation, no quiescence. WireClaw chip emits multiple messages per prompt (intermediate `[Agent]` traces, wrap-up) + unsolicited self-firing-rule messages + `/clear` echoes; pop-first mispairs at scale.
- **Phantom-prompter hypothesis investigated and ruled out** — chip-side `[TG] Message from <id>` confirmed every incoming message is from the operator's own Telegram account; no foreign sender.
- **Harness fix applied:** collect-all-until-quiescence (`SETTLE_S=5 s`) + `_is_substantive()` plumbing filter (drops `History cleared`, boot banners, `[Agent]`/`[TG]` traces); reply = last substantive. **Validated on c6-02:** LED 11%→**100%**, IP 4.5%→**100%**, temp 14.5%→**75%** (the temp "miss" is a genuine model error-reply, *correctly paired*). One known residual: unsolicited rule-fire messages landing mid-settle-window — mitigated by rule hygiene, irrelevant to the proxy-side salvage path.
- **Corpus salvage (Path A):** the canonical azza Ollama proxy log preserves true request/response pairing; coverage probe confirmed full continuous coverage of the run window (8,544 records, both chips, max gap 65 s). Salvage driver imports `merge_corpus.merge_records_into_turns`, walks 303 sessions, filters by (client_ip + ts window) → **`bench/fork/lora/corpus/v1.1-overnight-2026-05-18.REPAIRED.jsonl` — 3,548 turns, on-topic temp 83.0% / led 78.1% / ip 88.5%.** The scrambled artifact is preserved at `bench/fork/lora/corpus/quarantine/v1.1-overnight-2026-05-18.SCRAMBLED.jsonl` with a README documenting the pairing bug.
- **Telegram backlog nuke (4.1.1 hygiene):** the original `phase_4_0_3_tgnuke.sh` only flushed `wireclawsap_bot` (8700…) — the wrong bot. New `phase_4_1_1_tgnuke.sh` flushes the actual fleet bots `wdl_c6_02_bot` (8467…) + `wdl_c6_03_bot` (8996…). Server pending=0 confirmed both. This is why this morning's Telegram noise persisted even after the 06:02 graceful stop.

### Known v1.1 residuals (targets for v1.3 training)

- **Indirect-reference LED bug:** prompts like "Set the LED to my favorite color" sometimes fire `led_set` with empty/default args instead of chaining `file_read('/memory.txt')` → parse color → `led_set`. Observed in 4.0.1 corpus + repeatedly in real-world Telegram interactions.
- **Reasoning-trace leak into wrap-up text:** the model occasionally emits its chain-of-thought scaffold ("Since you asked …, I called …, the result was …") instead of the natural-language answer Scott's persona wants. Documented at the wrap-up-coherence axis since Phase 1.
- **Pseudo-prose at ~5%:** generic "the tool call was successful." replies that don't carry the actual answer. Down from much higher rates earlier in the project (was a leading P03-redesign failure mode), but still present.

### Queued work (post-housekeeping)

- **Phase 4.0.4 firmware hardening** (deferred from 4.0.3 pivot): boot-time `/rules.json` revalidation against pin allowlist (currently a poisoned rules.json still boot-loops a flashed chip until cleared via the fragile HTTP window); broader `snprintf` accumulation audit across `devices.cpp`/`tools.cpp`; crash-detection watchdog to replace the `errors=0` heuristic (content-derived liveness — boot-banner-as-reply detection).
- **Phase 4.0.5 c6-01 reflash:** bring the pilot chip back into rotation once 4.0.4 hardening lands.
- **v1.3 training round:** gated on a labeled clean corpus. The REPAIRED 3,548-turn corpus is the immediate candidate post-Haiku-labeling. Custom training data targeting the indirect-reference LED bug and reasoning-trace leak is in scope for v1.3.
- **Aggregator `--since/--until` extension** (issue #69): `merge_corpus.py` currently has no time-window flag; the salvage driver provides this externally per session. Worth folding into the CLI.
- **Broader fleet expansion:** spin up c6-04, c6-05, … once the per-Pi capture path is reproducible. Constraint is provisioning cost (each chip needs its own bot + Pi pair). SDCARD_PROVISIONING.md captures the runbook.
- **Upstream PR follow-throughs** (P01, P02-redesign, P03-redesign, P06+P08): gated on Mario's response to P05 at https://github.com/M64GitHub/WireClaw/issues/12.

---

## Strategic position after bisect (2026-05-12)

**What the bisect resolved:** P05, P06, P01, P04 are not the regression source. The smoke-test test-5 failure ("Set LED to my favorite color" → wrong color) is a model+prompt-design issue: at temp=0.7, the model picks wrong colors with high frequency regardless of which patches are present, dominated by recency bias from the preceding "Set LED to red" turn. Lower temperature concentrates on a single deterministic wrong answer rather than reducing variance to find the right one. None of the patches in scope can fix this.

**What the bisect revealed beyond the original scope:** Wrap-up text coherence is a separate, more concerning axis. At various points across runs, llama3.1:8b emits factually-wrong narration that's not adversarial-prompt-dependent. Examples: claiming temperature was loaded from /memory.txt when temperature_read fired; fabricating tool calls (`(file_write(...))` as parenthesised pseudo-code) that didn't fire; correctly naming RGB values then claiming the visual result is a different color. This is a generation-side coherence problem that prompt engineering can soften but not eliminate.

**Design-criterion reframe (explicit):** The original deployment bar was implicitly "stock 8B handles all bench + smoke tests perfectly." That's not achievable at 8B on 8GB VRAM. The revised criterion is **"stock 8B handles typical Telegram interactions reliably; degraded behavior on edge cases is documented and not deployment-blocking."** Adversarial multi-turn recency tests and post-tool natural-language coherence failures fall under "edge cases" by this framing. This preserves the local-first, stock-model design goal without overpromising.

**Phased response:**

1. **Ship the 4-patch stack.** Bisect closure means P05, P06, P01 are safe for upstream. P04 still has the structural critique (net-additive prompt push displacing serial_text docs past the 4095 cut) — needs redesign before upstream PR, but fine to ship in fork as-is. F01 stays fork-only. P08 and P09 (write-side completeness and file-buffer caps) are queued follow-ups, fork-first.

2. **Run P02-redesign + P03-redesign experiments on hardware.** Cheap (days, not weeks). Tests whether the stock-model criterion is salvageable for current failure modes:
   - **P02-redesign:** compact ≤4000-char system prompt incorporating chain_create + time-based-rules guidance via compression, not expansion. Day-1 evidence said ruthless compaction wins for small models — never tested at runtime.
   - **P03-redesign:** selective example augmentation only on tools where Mode B (arg truncation) was empirically observed in baseline runs — likely `file_read` for memory recall and `device_register` for NATS subjects. Other 18 tools stay terse.
   - If these meaningfully change test-5 distribution and clean up test-2-style wrap-up coherence, the design criterion holds.

3. **If Phase 2 doesn't move the needle, pivot to custom bake.** The `agent-llama:v1` recipe: LoRA fine-tune llama3.1:8b base targeting recency-bias and wrap-up-coherence failure modes specifically. Curated training data from Phase-1 conversation logs. Weeks of work; uses bench + smoke as eval. Don't commit until P02/P03 redesigns are tried.

**Honest constraint flagged:** Even with custom bake, fundamental 8B limits remain. The 70B-vs-8B gap is real and not fully closable by training alone. The constitutional / SOUL.md layer will continue to need careful integration regardless of which model path wins.

**What this does NOT mean:** We are not abandoning the stock-model goal yet. We are not committing weeks to custom bake yet. We are using the cheap experiments to inform that decision deliberately.

## Phase 1 results and shipping decision (2026-05-12 ~14:30)

Phase 1's cheap experiments (P02-redesign + P03-redesign) are complete. They produced a clean two-part answer to the strategic question:

**Tool-correctness axis: SALVAGED on stock model.** P02-redesign (compact 4000-byte prompt) + P03-redesign (selective example augmentation on 3 tools) deliver project-best results:
- Test 5 "favorite color" prompt: n=2 reproducible canonical purple (first time in project history)
- Probe A chain_create: correct tool selection with integer args, no string-coercion bug
- Probe B periodic rule: succeeds first attempt, no retry/leak, rule fires end-to-end on chip
- T12 (clock_hhmm time-based rules): implicitly solved via rule_create example pattern
- Cumulative test-5 purple rate jumped from 1/9 (~11%) at step 4 to 4/13 (~31%) at step 6

**Wrap-up-coherence axis: NOT salvaged on stock model.** P03-redesign's augmented tool examples teach the model two things simultaneously: (1) correct structured tool-call syntax — desirable, and (2) prose-mimicry of that syntax in user-facing responses — undesired. Every step-6 Telegram response is Python pseudo-prose like `(file_write(path="/memory.txt", content="LED: purple"))`. This is a fundamental property of how 8B models interact with example-augmented prompts, not a P03-specific quirk. The bench classifier doesn't measure wrap-up text quality, so 20/22 bench score didn't predict this regression — exposes a bench methodology gap.

**A new third leak pattern was discovered:** function-call syntax (`funcname(arg=val, ...)`) in plain prose. P01-v1 catches XML/fenced patterns; P01-v2 catches naked JSON; neither catches function-call syntax. Worth a P01-v3 follow-up (small extension, ~10 lines using the same memmem-style scan).

### Shipping decision

**Ship the patch stack upstream now.** The functional axis is the deployment-critical one for an embedded AI agent; wrap-up coherence is a polish issue. Per `bench/fork/HANDOFF.md` etiquette: one issue + one PR at a time, P05 first (smallest, friendliest first contact with Mario), then P01 (v1+v2 combined as one coherent PR), then P06+P08 paired, then P02-redesign, then P03-redesign (with wrap-up coherence caveat documented). P04 superseded — skip. P09, P10 deferred. F01 fork-only.

### Custom-bake decision: DEFERRED, not committed

The cumulative evidence strongly supports the framing that bake is the **right tool to fix wrap-up coherence specifically** — prompt+tool engineering at reasonable effort cannot achieve both axes simultaneously on stock llama3.1:8b. But we have no immediate need to bake:
- Functional axis is ship-quality without bake
- The shippable patch stack is independent of model choice (works on stock or baked)
- Wrap-up coherence remains a parallel Phase-2 workstream with multiple cheaper options to try before bake:
  - **P01-v3:** detect function-call-syntax leaks at the chip layer (small)
  - **P02-v2:** add explicit "respond in plain English; never include code syntax" instruction at end of compact prompt (small)
  - **Custom bake (Phase 2 final option):** LoRA fine-tune llama3.1:8b on natural-language wrap-ups specifically. Weeks of work; use as eval the cumulative captured failure cases (probe-B prose leaks, P03's pseudo-prose wrap-ups).

The bake remains in the playbook. It is not the next move.

### Updated current-state pointer

**Current state (2026-05-12 ~14:30):** Phase 1 complete. Patch stack is shippable. Strategic question answered with a clean two-part decomposition. Next: activate the queued P05 upstream PR directive — first friendly contact with Mario at `M64GitHub/WireClaw`. Wrap-up coherence work continues as Phase-2 parallel workstream, not blocking upstream shipping.

**UPDATE (2026-05-12 ~15:30):** First external action complete. P05 upstream issue filed at https://github.com/M64GitHub/WireClaw/issues/12. Branch `p05-serial-send-clarification` pushed to `WhitneyDesignLabs/WireClaw` fork. PR not yet opened — gated on Mario's positive response on the issue per `bench/fork/PATCHES.md` etiquette. Standing by for response (could be hours, days, or weeks). When Mario responds, Cowork drafts the next move (PR open, comment reply, or close-out depending on his stance). Next upstream item in queue: P01 (v1+v2 combined), but not until P05 closes one way or another.

**UPDATE (2026-05-12 ~17:35):** P02-v2 hardware test complete with NEGATIVE result. Anti-mimicry instruction in CRITICAL line did not meaningfully change wrap-up coherence (~11% clean vs step 6's ~0% baseline). Per pre-stated criteria, this is outcome 3 (escalate to bake). **Decision: ship existing patch stack as-is, DEFER custom bake.** The patches deliver substantial value (chain_create works, periodic rules end-to-end, P01 leak detection chip-validated in production twice now); the wrap-up coherence gap is documentable as a known limitation that prompt engineering cannot fix at 8B+example-augmentation stack. Bake remains in the Phase-2 playbook but is not committed. P02-v2 will NOT ship — v4 remains canonical compact prompt. Chip reverted to v4 via web UI Path A.

**Web UI Path A confirmed.** Web UI Prompt tab edit-save-reboot path works reliably. Future prompt iterations skip the uploadfs+reconfig+memory-restore dance entirely (~60 seconds instead of ~5-10 minutes). Significant workflow improvement for any future prompt-side experiments.

**P01 (v1+v2) PR prep complete in parallel.** Drafts at `sync/drafts/p01_{issue,pr,gh_commands}.md`. Branch `p01-prose-tool-call-leak-detector` exists locally on `upstream/main` with squashed commit `1ec16c7` (138 lines, 3 files). Gated behind P05 (#12) per etiquette — no posting until P05 resolves.

**Current state (2026-05-12 ~17:35):** Shipping decision finalized. P05 (#12) filed; P01 drafts ready and queued; remaining patches (P06+P08, P02-redesign, P03-redesign) await their turn in sequence. Bake deferred. Next chip-side work: real sensor integration (Scott working on screw terminals for ESP32-C6-02 in parallel; DHT22 or similar read sensor is the next-logical add). Documentation work (fork README explaining what's different from upstream + the documented wrap-up limitation) is the next-natural offline writing task.

## PIVOT 2026-05-12 evening — to Modelfile bake

Scott explicitly pivoted the primary workstream from firmware/prompt tweaks to a custom Ollama Modelfile bake on azza. Rationale: Phase 1 conclusively established that prompt engineering on stock llama3.1:8b cannot fix the wrap-up coherence axis at 8GB VRAM. The bake is the right tool. The fork and the baked model become a package deal in the repo.

**Working name for the bake:** `wireclaw-agent:v1`. Base llama3.1:8b (per the WireClaw bench's headline pick, not the SAP-era's qwen3:8b choice). Identity "WireClaw-Agent" for public-package friendliness (SAP variant later, one-line identity swap). Condensed 9-article SOUL constitution. ~20 WireClaw-shaped tool examples covering led_set, temperature_read, file_read/file_write, rule_create (incl. clock_hhmm + interval_seconds + telegram), device_register, actuator_set, serial_send, etc. PARAMETER stop set to `<|eot_id|>` (llama3.1 EOT, not qwen's `<|im_end|>`).

**Critical architectural issue: Modelfile SYSTEM bypass (PROJECT_STATUS.md line 220).** WireClaw's `/v1/chat/completions` calls REPLACE the Modelfile SYSTEM directive with their own `data/system_prompt.txt`. Therefore baking SYSTEM and calling through WireClaw is silently no-op.

**Sequencing decision (Option 2 — landed 2026-05-12 evening after review):** Integration patch FIRST, bake SECOND. The reversed-from-original ordering ensures every chip test goes through the integrated path from the start — no "bake works in isolation but breaks on chip" intermediate state.

- **Phase 1 — COMPLETE (2026-05-13).** P11 chip-validated. All three proof tests pass. Branch `p11-use-modelfile-system` (1 commit, 18-line diff vs `upstream/main@ad84614`) compiles clean and ready for upstream PR slot after the existing P05/P01 queue. Patch doc at `bench/fork/patches/P11-use-modelfile-system.md`. Test 1 byte-proof: REQ_BODY shows zero `role:"system"` entries when flag on. Test 2 behavioral: model relies on `tools` array for tool-name knowledge, has no WireClaw-system-prompt-specific knowledge when flag on. Test 3 regression: stock behavior preserved with default-off (`led_set` fires red; REQ_BODY grows back to ~13 KB / 3144 prompt tokens, consistent with `cfg_system_prompt` restored). **Chip is currently on `p11-use-modelfile-system` (flag=false default), ready to be reflashed onto a `bake-integration` branch in Phase 2B.**

  Phase 1 yielded six recommendations folded into the v1 Modelfile recipe and the Phase 2 directive: tools array carries tool-name/schema knowledge (bake teaches identity/policy/wrapping not tool repetition), model defaults to immediate tool-calling without system prompt (bake adds "conversational default" guidance), wrap-up coherence remains weight-level concern (LoRA future), `/memory.txt` injection is suppressed too (bake teaches `file_read('/memory.txt')` for memory recall), endpoint path detail (operator's `api_base_url` determines /v1/chat/completions vs /api/v1/...), boot loads /history.json from LittleFS (fresh-flash + /clear is canonical pre-test state). Plus operational lesson: serial monitor must use COM17 (USB-CDC), not COM16 (USB-JTAG).

- **Phase 2A — COMPLETE (2026-05-13). 9/9 PASS first try.**
  - T1 Identity ✓ ("WireClaw-Agent, Project Opengates, Whitney Design Labs, SOUL.md"). CONVERSATIONAL DEFAULT directive landed — no spurious `device_info` tool call.
  - T2 Refusal ✓ (refused weapon-build; did NOT cite Article 3 by number — v1.1 nit, non-blocking).
  - T3 Honesty ✓ (admits no live-weather access, no fabrication).
  - T4 LED red ✓ `led_set({r:255,g:0,b:0})`.
  - T5 Chip temp ✓ `temperature_read({})`.
  - T6 Memory recall cold ✓ `file_read({path:"/memory.txt"})` — MEMORY ACCESS directive landed.
  - T7 Periodic rule ✓ `rule_create` with `condition:"always"`, `interval_seconds:120`.
  - **T8 Time-based rule ✓** `rule_create` with `clock_hhmm`, `condition:"eq"`, `threshold:1012`. The bench T12 failure point that stock llama3.1 missed on every truncated-prompt variant — bake's empirical value demonstrated.
  - **T9 Compound favorite-color ✓** TWO tool calls: `file_read` then `led_set({r:128,g:0,b:128})`. Project nemesis — passed 1/9 (~11%) at step 4, 4/13 (~31%) at step 6 across all prompt variants — closed on curl side via bake.
  - Build ~120 ms. Total wall ~30 s. VRAM 6376 / 8192 MiB → 1.8 GB headroom for num_ctx push in v2.
  - Two v1.1 candidates filed (non-blocking, deferred until Phase 2B closes): add explicit refusal example citing Article 3 number, add "SOUL.md is a proper noun, do not expand" directive (T1 invented "Software for Understanding and Lifecycle" as expansion — Article 2 fabrication).

- **Phase 2B — COMPLETE (2026-05-13). Verdict: DIAGNOSE.** All three DIAGNOSE triggers fired on the 4-of-5 partial battery (Scott stopped at smoke #4 once results were conclusive). Headline finding: the bake fixes neither pseudo-prose nor — more concerning — fabrication of action narrations. Smoke #2 fabricated "The LED is now purple" with no led_set tool call fired (Article 2 Truth violation). Smoke #4 hit a new tool-name collision failure (led_set RGB args under `file_read` function name slot) AND fabricated the success ("The LED is now purple" when LED visibly stayed red). Deepest finding: smoke #4's REQ_BODY replays smoke #2's fabrication back to the model as established history — a self-reinforcing fabrication loop. The bake's per-turn SYSTEM directive cannot retroactively unfabricate prior turns the model itself wrote. This is weight-level behavior; Modelfile SYSTEM iteration cannot fix it. Phase 1 recommendation #3 ("wrap-up coherence remains LoRA territory") empirically validated.

  Tool axis on chip regressed vs Phase 2A's clean curl results. Smoke #2 malformed args envelope (OpenAI response shape leaked INTO the arguments slot). Smoke #4 tool-name collision is a new failure pattern not seen in curl T9. The chip's agentic loop + tools-array + multi-turn history context degrades calling ability versus single-turn direct curl despite identical model weights.

  Foundation passed: P11 flag working byte-level (REQ_BODY contains zero `role:"system"` entries); memory survived reflash; CONVERSATIONAL DEFAULT and MEMORY ACCESS directives both landed. Bake passes its own axis (identity, refusal substance, single-turn tool correctness); chip-integration is where it breaks.

  Chip currently sits on `p11-test` firmware + `cfg_model="wireclaw-agent:v1"`. Both baked and stock models preserved on azza; rollback via web UI = change model field back to llama3.1:8b, save + reboot.

- **Phase 2C — ACTIVE (see `sync/to_code.md`).** Ship v1 as opt-in package on `WhitneyDesignLabs/WireClaw` with documented limits. Strategic decision (Scott + Cowork): bake genuinely passes its own axis (identity, refusal substance, single-turn tool correctness on T8 clock_hhmm and T9 favorite-color compound — empirical wins prompt engineering couldn't deliver). Wrap-up coherence + multi-turn fabrication are LoRA territory; that's Phase 3, not blocking the ship. Public package = fork branches (P05/P01/P11 PR-ready singletons + integrated WhitneyDesignLabs production branch) + bake recipe in tree + README delta honest about limits + Phase 2B traces saved as Phase 3 seed corpus.

- **Phase 3 — ACTIVE (sub-phase 3.0 in progress as of 2026-05-15).** Full plan in `bench/fork/lora/PHASE3.md`. LoRA fine-tune on llama3.1:8b base targeting the wrap-up fabrication failure mode specifically, using the chip-fleet + Pi-cluster as a distributed corpus capture rig. Sub-phases 3.0 (extend bench harness with Claude-judge wrap-up classifier) → 3.1 (corpus capture, 1500-3000 multi-turn conversations) → 3.2 (labeling + curation via Claude API tiered) → 3.3 (QLoRA training on local 1080 + cloud bursts) → 3.4 (eval on tool correctness + wrap-up coherence + general-reasoning preservation) → 3.5 (package wireclaw-agent:v2 + retest + public ship). Estimated 8-12 weeks wall clock, under $200 operating cost, no GPU purchases needed.

  **Hardware fleet status (2026-05-13):** 6 additional ESP32-C6 16MB modules on order beyond the 3 already in inventory — projected fleet of 9 chips when delivery completes. GTX 1070 training-rig prep directive issued to Code 2026-05-15 (`sync/to_code.md` Thread B) — gated on Scott physically powering the box on. Phase 3.0 (wrap-up classifier) kicked off 2026-05-15 by Cowork: rubric + `bench/wrap_up_classify.py` written, deterministic layer self-check-passing; the >=90%-agreement Haiku validation gate is still pending hand-labels. See `bench/fork/lora/PHASE3.0-wrap-up-classifier.md`.

  **Rig vision (`bench/fork/lora/RIG.md`):** Scott signaled intent (2026-05-13) to build a self-contained AI data collection / training rig — open frame or rack-mounted, integrating ESP32 fleet + Pi cluster + PoE switch + router + NUC PC(s) + the two GPU systems into a coherent physical lab. Form factor and topology TBD; rig document tracks the vision as it accretes.

- **Open questions (`OPEN_QUESTIONS.md`):** 23 deferred decisions across 8 categories — Phase 2C ship architecture, v1.1 disposition, upstream/Mario timing, deferred patches (P08/P09/P10/F01/P12), Phase 3 specifics, real sensor integration, publishing strategy, chip operational hygiene, documentation hygiene. Scott chose to document and defer rather than answer ad-hoc; future sessions read this file when an answer becomes blocking and mark resolved questions DONE inline.

**Wrap-up coherence:** acknowledged in PLAN.md as NOT addressed by Modelfile SYSTEM bake alone. SYSTEM nudges style with explicit instructions but cannot retrain weights. LoRA is the eventual answer for the wrap-up axis. v1 documents this as a known limit; if Phase A bakes excellent tool-correctness while wrap-up remains uneven, that confirms the LoRA-for-wrap-up framing for Phase 2 future work.

**Files added this round:**

- `bench/fork/bake/wireclaw-agent-v1.Modelfile` — canonical recipe (~5 KB, SYSTEM block ~1500-2000 tokens)
- `bench/fork/bake/PLAN.md` — strategy notes, success criteria, Phase A/B/C scope
- `sync/to_code.md` — Phase A directive for Code (rewritten — supersedes previous standing-by state)

**Upstream PR queue: on hold, NOT abandoned.** P05 (#12) still awaits Mario's response. P01 (v1+v2 squashed at `1ec16c7`) drafts stay queued behind P05 per etiquette. When Mario engages on P05, Cowork drafts the next move regardless of bake progress.

**UPDATE (2026-05-15) — Cowork session.** Phase 2C fully closed: Code confirmed the repo description updated and verified on origin — the last outstanding ship item. Two threads kicked off this session:

- **Phase 3.0 started.** Wrap-up coherence classifier: `bench/fork/lora/PHASE3.0-wrap-up-classifier.md` (4-class rubric `clean` / `pseudo-prose` / `fabricated` / `contradictory`, worked-example bank, two-layer architecture, validation plan) + `bench/wrap_up_classify.py` (deterministic detectors + Haiku judge + `--self-check`). Deterministic layer agrees 4/4 with the Phase 2B seed corpus. NOT complete: the >=90%-agreement Haiku validation against 50 hand-labels — needs the hand-labeled set built first.
- **1070-prep + cleanup directive issued** to Code at `sync/to_code.md`: Thread A deletes the 4 stale fork-style branches + the stray `-H` file; Thread B preps the GTX 1070 as the Phase 3.3 training node (gated on Scott physically powering it on — Code can't SSH a powered-off box). Headline risk flagged for Thread B: the 1070 is Pascal (CC 6.1) and recent bitsandbytes/Unsloth may not support it — the B3 smoke-test confirms fit-or-not before Phase 3.3 depends on it.

**UPDATE (2026-05-15, later) — Code directive complete; ESP32-C6 modules arrived.**

- **Thread A done.** Four stale fork-style branches deleted from origin (content-safe-fenced), `-H` removed, `p05-serial-send-clarification` (#12) untouched.
- **Thread B done — headline finding.** The GTX 1070, now **`k-scale-trainer`** (Ubuntu 24.04.3, i5-4590, 23 GB RAM, 90 GB free, GTX 1070 8 GB / driver 580.95.05 / Pascal sm_61, reachable keyless on the tailnet), **can host an 8B rank-32 4-bit QLoRA — but only via a pinned peft+bitsandbytes stack, NOT Unsloth.** Modern Unsloth (torch 2.10) fails on sm_61 (torch dropped Pascal kernels); peft's default kbit-prep OOMs. Working stack: torch 2.4.1+cu121, bitsandbytes 0.43.1, transformers 4.44.2, peft 0.13.2 + lean kbit-prep + `expandable_segments`. Smoke-train: peak 6.52 GB / 7.92 usable, ~1.3 s/step at seq-len 256, loss converged. Headroom thin (~1.4 GB) — real-corpus seq-len needs profiling before locking a config. Full recipe in `bench/fork/lora/RIG.md`; PHASE3.md corrected (Unsloth → pinned peft+bnb; Pascal risk re-characterised).
- **Open items needing Scott:** (1) power the box down — no passwordless sudo; recommend adding a `NOPASSWD: poweroff` sudoers rule so future sessions can run the Phase 3.3 wake→train→sleep cycle unattended; (2) relax the Tailscale ACL from `check` (12 h re-auth) to `accept` for unattended multi-hour training.
- **ESP32-C6 modules arrived (2026-05-15).** Phase 3.1 capture-fleet hardware is now on hand. Initial plan was 7 chips in parallel (matches the 7-Pi cluster); **revised 2026-05-15 evening to 3 active chips + 1 status-display rack unit** on the basis of azza's GTX 1080 saturating at ~3 concurrent chips. Rack-layout planning underway — Cowork drafted a layout diagram (the original 7-chip version; the 3+1 version supersedes).

**UPDATE (2026-05-15, even later) — Single-pair pilot complete; project nemesis PASSED.**

All three pilot threads (C / D / E) complete. The first hardware flash of `wdl-v1` works end-to-end. **Major win:** the Phase 2B project nemesis (smoke-4: "set LED to my favorite color" on the purple-memory path) PASSED cleanly on `wdl-v1 + wireclaw-agent:v1` — clean parallel `file_read` + `led_set({r:128,g:0,b:128})`, LED physically purple (operator-confirmed), truthful wrap-up. The exact prompt that failed in Phase 2B via tool-name collision + fabrication now works. `wdl-v1 + bake` resolved that specific failure mode on the chip-integration path.

- **Thread C (pilot chip):** Pilot ESP32-C6 flashed `wdl-v1` (commit `4d07a81`), configured for `wireclaw-agent:v1` baked mode + new bot `wdl_c6_pilot_bot`, chip lives at `192.168.1.19`. 9/10 prompt smoke battery driven via Telegram (p08 threshold rule skipped — backfillable). Corpus + labels written to `bench/fork/lora/seed-corpus/pilot-2026-05-15/{corpus.json,labels.json}`.
- **Thread D (EvoBot):** Pi #1 software stack deployed at `~/wireclaw-phase31/` + `~/phase31-venv/`. Ready for Phase 3.1 Telethon driver. Throttle 0x50005 flag noted for PSU procurement before scale-up.
- **Stretch E (Ollama proxy):** Stream-3 proxy script + deployment + start/stop commands validated end-to-end and idle. Chips still on `:11434` for now; `cfg_api_base_url → :11435` cutover is a deliberate future Phase 3.1 step. Recipe in `bench/fork/lora/CORPUS_CAPTURE.md`.

**Residual failure modes** (known LoRA targets, NOT pilot blockers):
- **Pseudo-prose wrap-ups** on p01 (chip temp), p02 (LED red), p04 (mild) — same family as Phase 2B smoke-1.
- **p07 fabricated rule:** `rule_create` fired with sane periodic args but missed the REQUIRED `rule_name` → tool errored → wrap-up declared "the rule has been created." Stock-8B rule-arg miss + fabricated-success.
- **p10 fabricated LED state:** post-memory-write compound. `file_read` correctly returned "blue," but `led_set` fired with EMPTY args → chip executed RGB(0,0,0) → LED stayed off, wrap-up claimed "The LED is now blue." A new flavour of the nemesis: correct tool selection, dropped args, fabricated wrap-up. High-value LoRA training signal.

**Classifier gaps surfaced** (Phase 3.0 next iteration): the deterministic `wrap_up_classify` layer caught p07 (via all-tools-errored heuristic) but missed pseudo-prose patterns on p01/p02 (verb-tense / backtick-quoted tool names / whole-wrap-up parenthesisation) and the p10 empty-args fabrication (sees `led_set` fired by name, doesn't check args or `tool_results` ground-truth). Concrete regex fixes + a tool-results cross-check proposed in `bench/fork/lora/PHASE3.0-wrap-up-classifier.md` ("Gaps surfaced in pilot capture"). Pilot corpus extends the worked-example bank toward the 10+/class target.

**Pilot findings folded into docs:**
- Fresh chips need `pio run -e esp32-c6 -t uploadfs --upload-port COMxx` once on first flash to initialize LittleFS — `bench/fork/HANDOFF.md` updated.
- Chip firmware has no generic web file endpoint — `/history.json` is not pullable via web UI; only specific `/api/*` routes exist. For the pilot, stream 2 came from the COM serial monitor; at-scale uses the proxy. Note added to `bench/fork/lora/CORPUS_CAPTURE.md`.

**Chip / azza / Pi state at end of round:**
- Pilot chip: live on `wdl-v1` + `wireclaw-agent:v1` at 192.168.1.19; physically moved from workstation USB to EvoBot USB during 3.1.2.
- C6-01 (dev chip): unplugged, retains `p11-test` + `wireclaw-agent:v1` for the baseline role.
- C6-02 + C6-03: new fleet members live on `wdl-v1` + `wireclaw-agent:v1` at 192.168.1.15 and 192.168.1.47 respectively (added 2026-05-16 in 3.1.2). Paired with pi02 / pi03.
- EvoBot, pi02, pi03: online; full Phase 3.1 software stack on each; each authenticated with its own Telethon session against its paired chip's bot.
- azza: proxy persistent on `:11435`, ufw open, rule-purge endpoint wired.
- Upstream PR queue (P05 #12, P01, P11): unchanged, on hold.

**UPDATE (2026-05-15 evening) — overnight throughput run + capture-fleet topology pivot.**

The single-pair fully-automated capture loop has been running unattended on EvoBot since this evening. Will self-stop at ~07:00 MST per `overnight_capture.sh`. Morning wrap-up directive (Phase B in `sync/to_code.md`) pulls + aggregates + classifies + health-checks; deliverables include throughput/hour, latency profile, label distribution, per-prompt breakdown.

**Strategic pivot from the original 7-chip target to 3 active capture chips + 1 status-display rack unit.** Driven by an explicit GPU-saturation calculation against azza's GTX 1080: per-chip Ollama load is ~280 calls/hour, single-chip GPU duty cycle is ~39%, theoretical Ollama ceiling at default `OLLAMA_NUM_PARALLEL=1` is ~720 calls/hour = ~360 turns/hour aggregate, saturating at ~3 concurrent chips. 4+ chips add queue depth, not corpus growth. Full reasoning + the per-N-chips table in `bench/fork/lora/PHASE3.md`'s "Hardware scaling math" section.

Implications:

- Phase 3.1.2 now scopes to flashing 2 more chips (not 6), provisioning 2 more driver Pis (not 6), creating 2 more BotFather bots, and standing up the 4th-Pi status-display rack unit. PoE-HAT cost drops from $175 to ~$100.
- Persona variety comes from per-session persona rotation across the 3 driver Pis rather than from chip count. Personas 02-04+ still wanted before sustained captures.
- Two reversible-later levers identified if/when we want to push past the 3-chip ceiling: `OLLAMA_NUM_PARALLEL=2` on azza (cheap experiment; VRAM-permitting), or k-scale-trainer (1070) as a second inference host on non-training nights.

**Hardware fleet status (2026-05-15 evening):** 1 ESP32-C6 in production capture (Pilot @ `:11435`) + 1 baseline (C6-01) + 7 spares. 1 driver Pi active (`evobot`) + 6 Pi 3s in stock; 3 of those allocated to upcoming driver/display roles, 3 remain spare. Stream-3 proxy persistent on azza. EvoBot Pi 3 PSU throttle flag `0x50005` noted; procure proper 2.5 A units before the sustained-load week.

**UPDATE (2026-05-16) — Phase 3.1.2 complete. 3-pair fleet alive.**

EvoBot↔C6-Pilot, pi02↔C6-02, pi03↔C6-03 — all online, each with its own
Telethon session and dedicated chip-bot. First multi-pair capture validation:
~200 turns aggregated across the three chips in ~15 min wall time, zero
errors, cross-pair isolation clean (each chip's per-chip corpus shows
exactly one `client_ip`).

**Throughput measurement vs. PHASE3.md saturation math:**
- Predicted at 3-chip saturation: ~120 turns/hr per chip (~360/hr aggregate ceiling).
- Observed at 3-chip parallel: ~61–75 turns/hr per chip (~210/hr aggregate).
- Conclusion: Ollama-contended but well under saturation. 8-hour overnight ≈
  ~1700 conversations — squarely in the PHASE3.md "comfortable" target
  (1500–3000) for Phase 3.1 corpus capture. Adding the
  `OLLAMA_NUM_PARALLEL=2` experiment from Q25 isn't needed for this corpus
  goal; deferring.

**Hardware state at 3.1.2 close:**

- 3 active capture chips: Pilot (192.168.1.19), C6-02 (192.168.1.15), C6-03 (192.168.1.47).
- 3 driver Pis: evobot (192.168.1.51), pi02 (pi02.local DHCP), pi03 (pi03.local DHCP).
- Per-pair USB wired: each Pi's USB-A → its chip's CH343 USB-C for power+serial.
- New PSUs validated on pi02 and pi03 (no `0x50005` throttle); EvoBot still on the
  original wall-wart (showing throttle — replacement queued).
- C6-01 baseline: sealed, untouched.
- 4 Pi 3s + 5 ESP32-C6 chips remain as spares.

**Phase 3.1.3 (persona rotation overnight on the validated 3-pair) is unblocked.**

**UPDATE (2026-05-17 morning) — Phase 3.1.3 corpus delivered. Phase 3.2 unblocked.**

7-persona overnight rotation ran on the 3-pair fleet from ~20:26 to ~07:02 UTC (with a ~20-min Phase L recovery delay for persona-files-on-clones). Self-stopped clean at the morning-window boundary, 0 errors across all 3 Pi wrappers.

**Corpus delivered:**
- 3601 proxy-reconstructed turns / 4430 JSONL turns across 444 sessions.
- Per-persona distribution near-perfect: ~620-650 turns per persona across the fleet.
- Cross-pair isolation clean (each chip's per-chip corpus contains exactly one `client_ip`).
- Files: `bench/fork/lora/corpus-raw/3.1.3-2026-05-16-{pilot,c6-02,c6-03}.json`.

**Label distribution (deterministic layer):**
- clean ~12%, pseudo-prose ~21%, fabricated ~18%, uncertain ~50%.
- Fabrication signal covers every important pattern: claimed-without-doing, errored-tool-claimed-success, wrong-args fabrication, prose-leaked JSON, and the p04 LED-favorite-color nemesis at 80% reproduction (90/113 turns) — the strongest single class of training data we have.

**Domain coverage validates persona expansion:**
- gpio_write 1370, rule_create 522, gpio_read 408, file_read/write 554, actuator_set 212, sensor_read 113, rule_delete 100. The new automation/robotics/telemetry personas drove the GPIO + automation + sensor traffic the project actually targets.

**Hardware-side caveats (recorded; corpus impact is recoverable):**

- **C6-Pilot rebooted ~06:56 UTC** (recovered); **C6-02 + C6-03 HTTP servers wedged** end-of-run (network alive, app task hung) — chip-side firmware-stability issue under ~11h sustained load. **Top hardware priority before any longer run.** Needs power-cycle of C6-02/03 + serial attached to ≥1 chip on the next run to capture backtrace.
- **EvoBot Pi was on the wall-wart during the run** (`get_throttled=0x50005` active). Now resolved (Scott moved all 3 Pis to the new +5V/19A rail post-run). Was the dominant cause of EvoBot's per-pair yield asymmetry (pilot 549 turns vs c6-02 1868, c6-03 1184).
- **Rule-purge failures escalated late** (EvoBot 118/153 by end-of-run) — Code flagged this as a "late-night quality cliff" but the label-rate distribution across hours shows **no actual quality cliff** (05-07 UTC window matches the rest of the run within stochastic variation). Treat the corpus uniformly in curation.

**Phase 3.2 curation sequence** (Cowork-side, next move):

1. Haiku-label the 1788 uncertain turns (~$2 API spend, ~20 min wall).
2. Stratified hand-labelled 50-turn validation set for the Phase 3.0 ≥90% Haiku-agreement gate (Scott + Cowork, ~60-90 min).
3. Junk filter: empty wrap-ups, chip-wedge-window turns, the small amount of 3.1.2 residual the aggregator's pre-filter caught.
4. Resample for class balance (LoRA training prefers balanced positive/negative).
5. Phase 3.3 training prep — corpus drops onto k-scale-trainer (1070) for QLoRA.

**Aggregator follow-up:** add `--since/--until` time-window. Today's manual prefilter was a stopgap; multi-run days will keep tripping this. Cowork-side change.

**UPDATE (2026-05-17 afternoon) — Phase 3.2 steps 1, 1b, and 2 closed.**

**Step 1 — Haiku-label V1.** Ran `wrap_up_classify.py --use-haiku` against all three corpora in parallel. 3601 turns labeled in ~50 min, 9 errors (0.25%), ~$6 spend. Combined V1 distribution: fab 57%, clean 33%, pp 10%, contradictory 0.8%. 72% deterministic-vs-Haiku disagreement triggered hand-back; root cause was not Haiku error but the deterministic layer's "clean" exit asserting clean on absence-of-markers rather than presence-of-correctness. Code's diligence here (stopped rather than auto-proceeded) was right.

**Step 1b — Re-label V2 with demoted deterministic.** Deterministic layer demoted: emits only `pseudo-prose`/`fabricated`/`null`, no longer asserts `clean`. Haiku alone owns the clean verdict. Prompt-caching attempt deferred — the judge prompt is 448 tokens, below Haiku's 2048-token cache minimum, so caching can't engage. Ran uncached at ~$3.3 / ~49 min. Code flagged a real new problem during the V2 run: the deterministic backtick-tool pseudo-prose marker fires on legitimately-clean prose that just *names* a tool in backticks. Under det-wins precedence, ~191 turns Haiku would have called clean got demoted to pp/fab. V2 ships as-is for step 2 calibration; the backtick-tool marker is now a known issue queued for the rubric-refinement pass.

**Step 2 — Hand-label calibration.** Methodology deviation: Scott opted for LLM-vs-LLM calibration (Cowork labels in lieu of human labels) to preserve momentum. The deviation is documented in `bench/fork/lora/corpus-labels/COWORK_LABELS_REPORT.md`; known caveat is shared-model-family bias (Haiku and Cowork are both Claude). 64-turn sample stratified across 4 classes × 3 chips × 7 personas, seed 42.

Results: per-class agreement on clean / pp / fab is solid (87% / 90% / 80%); contradictory class is a rubric mess (4.2% agreement). Drilled into the contradictory disagreements: 22 of 24 Haiku-contradictory turns were either reclassed by Cowork as `fabricated` (for response-vs-tool-result mismatches like "LED is now blue" when RGB(128,0,128) is purple) or `clean` (for response-matches-action-but-chip-ignored-memory cases). Rubric had two competing definitions in play — strict ("response self-contradicts within its own text", Cowork) vs liberal ("response inconsistent with tool result OR memory OR user intent", Haiku). For training-data filtering the liberal interpretation is more useful.

**Decisions for Phase 3.3 prep:**

- **Drop the contradictory class for training purposes.** Merge to fabricated. The class can't be calibrated under the current rubric and every turn either labeler called contradictory was bad chip behavior either way.
- **Use the strict-clean intersection as the high-confidence positive training pool.** `final_label == 'clean' AND cowork_label == 'clean'` (where Cowork-applicable). On the 64-turn sample: 13/64 = 20.3%, extrapolating to ~731 strict-clean turns out of 3601. Workable for a Phase 3.3 LoRA SFT (above the 500-turn floor) and every turn in the pool is double-confirmed clean by two labelers from a shared model family. The 112-turn cost vs the Haiku-only pool (~843) is acceptable.
- **Persona imbalance remains a Phase 3.3 prep concern.** basic_operator 64.5% clean vs sensor_telemetry 12.9% clean. Resolved at training-prep time via stratified resampling or weighted loss, not via another overnight (hardware is still pending).
- **Plan a small human-anchor pass in Phase 3.3 evaluation** (~20 turns), not as calibration of the labels but as a sanity check on the trained LoRA's outputs against shared-model-family bias.

**Spend to date:** ~$7 across both Haiku rounds ($21.45 starting balance, ~$14 remaining). The original "$109 vanished" mystery was resolved earlier in the session: $109 was Scott's claude.ai subscription bill (consumer side), never an API credit. API survey credits had likely expired separately.

**Phase 3.2 status:** Steps 1, 1b, 2 closed. Steps 3-5 (junk filter / class balance / training prep) in progress — held mid-flight by SOUL.md recovery (see below).

**UPDATE (2026-05-17 evening) — SOUL.md recovered. Constitution drift discovered. Two-tier constitution adopted before training.**

While Code was mid-execution on Phase 3.2 step 3 N3 (training-data format conversion), Cowork paused to verify the system-prompt source against the canonical constitution. Scott provided the full SOUL.md (25,860 bytes, all 26 articles per v0.2.0 — Articles 0-25 inclusive). Diff against the wireclaw-agent:v1 Modelfile SYSTEM block revealed significant **constitutional drift**:

- Modelfile says Article 4 = Privacy. Canonical Article 4 = Irreversibility Doctrine.
- Modelfile says Article 5 = Non-Deception. Canonical Article 5 = Cascading Consequence Awareness.
- Modelfile says Article 7 = Resource Stewardship. Canonical Article 7 = Respect for Autonomy (with the three-tier advise/warn/refuse framework).
- Modelfile says Article 10 = Identity Stability. Canonical Article 10 = Breaking Cycles of Escalation.
- Modelfile entirely missing Article 0 (Supremacy Clause — the conflict-resolution mechanism), Article 12 (Safety Hierarchy — the priority ordering), and Articles 6, 8, 9, 11, 13, 14, 17, 18, 19, 20, 21-25.

Effect: wireclaw-agent:v1 was baked against a hand-summarized SAP-era ancestor that drifted from canonical OpenClaw/Opengates constitution. For project goals of a faithful first-custom-model release (publicly via GitHub + HuggingFace), this had to be corrected before LoRA training.

**Two-tier constitution adopted:**

| File | Size | Tokens | Role | Coverage |
|---|---|---|---|---|
| `SOUL.md` | 25,860 B | ~6,465 | Canonical source-of-truth | All 26 articles, full prose |
| `SOUL-LOCAL.md` | 5,829 B | ~1,457 | Training-time system prompt + cloud deployment | All 26 articles, distilled |
| `SOUL-CHIP.md` | 3,069 B | ~767 | Chip runtime (fits 4095-byte cfg_system_prompt limit at 75%) | 15 operational-critical articles |

SOUL-CHIP includes Articles 0, 1, 2, 3, 4, 7, 12, 13, 14, 15, 16, 18, 19, 20, 25. Articles 5, 6, 8, 9, 10, 11, 17, 21-24 are relegated to weight-baking via training — the model learns them through training examples rather than runtime context.

Scott reviewed and blessed both distilled files. All three live in `bench/fork/lora/training-data/constitution/`.

**Architectural correction adopted at the same time:** LoRA training base is `meta-llama/Llama-3.1-8B-Instruct` (canonical Meta weights), NOT `wireclaw-agent:v1`. Reason: Modelfile bakes don't modify weights — they're configuration wrappers, so v1's weights are bit-identical to Llama 3.1 8B Instruct. Training against the OEM base directly gives cleaner provenance for the HuggingFace public release.

**Net effect on Phase 3.2 step 3-5:** Code resumes from N3 with the corrected system-prompt source (SOUL-LOCAL.md). 681-turn captured corpus and persona audit are unchanged (system prompt doesn't affect them). Adds a new N3.5: generate ~80-120 synthetic constitutional examples covering the 11 articles not in SOUL-CHIP, to ensure weight-baking covers all 26 articles' principles even when chip-runtime context only carries 15. Total training corpus after step 5: ~760-800 examples (681 captured + synthetic).

**Phase 3.2 status updated:** Steps 1, 1b, 2 closed. Step 3 N1+N2 closed. Step 3 N3 onward in progress with corrected directive.

**Files in `bench/fork/lora/corpus-labels/`:**
- `3.1.3-2026-05-16-{pilot,c6-02,c6-03}.haiku.json` — V2 labels (current source of truth)
- `3.1.3-2026-05-16-{pilot,c6-02,c6-03}.haiku.v1.json` — V1 labels (preserved for comparison)
- `3.1.3-handlabel-sample-v1-labeled.json` — 64-turn sample with both Haiku and Cowork labels merged
- `COWORK_LABELS_REPORT.md` — full step-2 calibration report

**Owner:** Scott Whitney / WhitneyDesignLabs
**Upstream:** [M64GitHub/WireClaw](https://github.com/M64GitHub/WireClaw) (MIT, Mario Schallner)
**Fork:** [WhitneyDesignLabs/WireClaw](https://github.com/WhitneyDesignLabs/WireClaw) — created and ready for patches
**Stack position:** Edge actuator. Microcontroller-class continuation of OpenClaw → Gatekeeper → WireClaw lineage.

---

## For future sessions reading this fresh

If you are a new Cowork session, Claude Code instance, or future Scott returning after a break, read this file first. Then check `bench/fork/HANDOFF.md` for shipping mechanics, and `bench/fork/PATCHES.md` for the firmware modification plan. If you need the deep failure-mode context that informs all of the bench design and patch priorities, that lives in **Scott's Project Opengates context primer** (pasted into chat history, May 2026). Ask Scott for a copy if it's not in your context yet.

## What this project is

WireClaw is an MIT-licensed firmware that turns an ESP32 into an AI agent: you chat with it (Telegram / serial / NATS), and it configures GPIO, reads sensors, sets up automation rules, and runs them locally without an LLM in the loop. Three ESP32-C6 16MB boards are inbound for this build. The endgame is: forked WireClaw running on C6 with our patches applied, talking to a local Ollama on `azza.tail63f48.ts.net`, eventually exposing Zigbee/Home Assistant + MCP for integration with Scott's existing Fusion360 / FreeCAD / CNC tool chain.

## Architecture decision: WireClaw, not ESP-Claw

Reviewed Espressif's competing ESP-Claw framework. Decision: stay with WireClaw because:

- **ESP-Claw does not support ESP32-C6** (only S3 / C5 / P4). Scott's hardware is C6.
- ESP-Claw's local LLM support is technically possible but not headlined; WireClaw documents Ollama configuration as a first-class use case.
- WireClaw's smaller scope is easier to fork and modify than ESP-Claw's larger Lua-based framework.

Trade-off accepted: WireClaw is a solo-maintainer project (15 GitHub stars), so we're committing to maintaining a fork ourselves rather than relying on upstream to evolve.

## Current state

| Workstream | Status | Where |
|---|---|---|
| WireClaw vs ESP-Claw research | Done | chat history |
| WireClaw source audit (parser, prompt, tools, request shape) | Done | findings inline in `bench/fork/PATCHES.md` |
| Python tool-calling bench harness | Built and calibrated | `bench/run.py`, `bench/classify.py`, `bench/report.py` |
| Calibration run vs `opengates-agent:v1` | 20/22 (91%) | `bench/results/run-20260511T163604Z.md` |
| 5-model bench (existing library, truncated/stock) | Done | `bench/results/run-20260511T170249Z.md` |
| 5-model bench (new candidates, truncated/stock) | Done | `bench/results/run-20260511T181908Z.md` |
| Variant bench (full prompt + examples tools) | Done — surprising negative result | `bench/results/llama-full-examples.md`, `bench/results/opengates-full-examples.md` |
| Patch plan drafted | Done (with two patches flagged for redesign) | `bench/fork/PATCHES.md` + 7 patches in `bench/fork/patches/` |
| GitHub fork created | **Done** | https://github.com/WhitneyDesignLabs/WireClaw |
| `gh` CLI authenticated on workstation | **Done** (WSL, scope: `gist`, `read:org`, `repo`) | account: WhitneyDesignLabs |
| Fork cloned locally with upstream remote | **Done** | `/mnt/c/Users/homet/Documents/WireClaw-fork/` |
| Patches landed in fork | Not started | After hardware arrives + final patch redesign |
| Upstream PRs filed | Not started | After Scott primes Mario with issues |
| Hardware on the desk | **Done — board 1 alive** | ESP32-C6 rev 2, IP 192.168.1.27, mDNS wireclaw-C6-01.local |
| Firmware flashed (vanilla v0.4.0) | **Done** | via wireclaw.io/flash, captive portal config |
| Vanilla smoke test passed (cloud LLM) | **Done** | google/gemini-2.5-flash via OpenRouter |
| Local Ollama swap proven on chip | **Done** | llama3.1:8b via 192.168.1.60:11434, all tests pass, memory persists across model swap |
| Forked firmware build & flash | Pending | Task #10 |
| Patches applied to fork | Pending | Task #9 |

## Headline finding: prompt expansion HURTS small models

The single most important result of the whole session, and the one that overturned an earlier assumption:

The bench's stock test (truncated 4095-char prompt + 1-line tool descriptions) accidentally produces the best results. Restoring the "intended" full 7266-char prompt AND adding worked examples to tool descriptions (i.e., applying patches P02 and P03 as originally drafted) caused **catastrophic regression**:

| Config | opengates-agent:v1 | llama3.1:8b |
|---|---|---|
| Truncated prompt + stock tools | 20/22 (91%) @ 13.7s | 19/22 (86%) @ 3.0s |
| Full prompt + examples tools | 10/22 (45%) @ 29.8s | 2/22 (9%) @ 9.6s |
| Delta | **−45 percentage points** | **−77 percentage points** |

This is the Mode D (context drowning) failure that Scott's Project Opengates primer warned about, reproduced from a different direction. The truncation in WireClaw firmware is acting as **accidental gatekeeping**: by chopping off the chain_create / time-based-rules / rule-management guidance, it prevents small models from over-reaching for tools they can't handle correctly.

Implication: **ruthless compaction wins**. Naive expansion loses. P02 and P03 need to be redesigned as compaction-aware rewrites, not buffer/description expansion. See "Patch shipping plan" below.

## Final upstream-LLM recommendation (task #6)

**Primary headline path:** `llama3.1:8b` from Ollama's official library. Stock model, no Modelfile bake required. Pull with `ollama pull llama3.1:8b`. Configure WireClaw to point at `http://azza.tail63f48.ts.net:11434` (or wherever the user's Ollama runs). Use the existing truncated 4095-char system prompt and stock 1-line tool descriptions. Don't grow either.

Score: 19/22 (86%) on the WireClaw test suite at ~3-second average response time. The one accuracy gap vs the 20/22 leaders (T11_rule_periodic, where llama omits the `condition` field) is small and can be improved later via custom bake or selective tool augmentation.

Why llama3.1:8b over the higher-scoring opengates-agent:v1 / specialagentpuddy:8b (both 20/22):

- **Adoption friction.** llama3.1:8b is on Ollama's official library — anyone can pull it in 30 seconds. The custom-baked Qwen3 variants would require Scott to host or share Modelfiles, adding friction for any future user of the WhitneyDesignLabs fork.
- **Speed.** ~3 seconds vs ~14 seconds. For an embedded wire protocol where the user is waiting on Telegram, 3 seconds reads as instant; 14 seconds reads as broken.
- **Lower implicit endorsement burden upstream.** If Mario eventually adds a "recommended local LLM" line to WireClaw's docs, pointing to a stock Ollama-library model is much cleaner than pointing to a stranger's HuggingFace upload.
- **Accuracy delta is small.** 1 test out of 22 (95% confidence interval much wider than that gap).

**Backup path for cloud users:** `google/gemini-2.5-flash` via OpenRouter. Faster and more accurate than any 8B local; trivially configurable via WireClaw's web portal. Recommended for users who don't have local GPU and just want the chip to work well immediately.

**Power-user path (future):** Custom bake on llama3.1:8b base — see "Future custom-bake exploration" below.

## Other key findings

**opengates-agent:v1 and specialagentpuddy:8b validate the SAP-era Modelfile recipe.** Both Scott's custom-baked Modelfiles from Feb 2026 still tied for #1 raw accuracy (20/22) three months later, beating every stock 8B variant by at least 1 test. The "compact prompt + bake-once" pattern produced models that aged well. They lose the recommendation only on speed and adoption-friction grounds, not on quality.

**Critical firmware bug uncovered by audit:** WireClaw's response parser silently passes prose-leaked tool calls through to the user as plain text and saves them to history, reinforcing the bug on subsequent turns. Headless wire protocol nightmare. Patch P01 fixes this. Independent of the prompt-expansion finding; this patch stays valid.

**System prompt is silently truncated** at 4095 bytes on boot (buffer is `cfg_system_prompt[4096]`, shipped file is 7266 bytes). Drops `chain_create`, time-based rules, and rule management guidance — recreatable failure on tests T11 and T12 across every model. **But:** the truncation is acting as accidental gatekeeping that protects small models from drowning. The right patch is to rewrite the prompt to fit ≤4000 chars while including compressed time-based-rule guidance — not to grow the buffer. See revised P02 plan.

**Two prompt naming bugs** (still valid, independent of expansion finding):
- T02 ("Turn off the LED") fails on 3/5 models because the LED rules paragraph teaches `off_r/off_g/off_b` (which lives on `rule_create`) without disambiguating from `led_set`'s `r/g/b`. Patch P04 fixes — small targeted prompt rewrite, no expansion.
- T19 ("Send GET_TEMP over serial") fails on 2/5 models because the `serial_send` tool description says "newline appended" ambiguously. Patch P05 fixes — one-line description tweak, no expansion.

**xLAM-2 8B failed not on tool calling but on memory.** Server reported "model requires 21 GiB" when only 16 GiB system RAM available. The Q5_K_M quant + full-context KV cache exceeded budget. Salvageable with smaller quant (`Q4_K_M` or `Q3_K_M`) or `num_ctx=4096`, but not pursued because llama3.1:8b is the easier win.

**granite4.1:8b underperformed expectations.** 14/22 with 6 WRONG_TOOL failures, all picking `device_register` when `rule_create` was wanted. Behavior pattern, not parameter problem. Filed as "not the winner here."

**qwen3-nothinker actually performed worse than stock qwen3:8b.** Disabling Qwen3's thinking mode didn't help on these tests. Filed as a curiosity.

**voytas26/openclaw-qwen3vl-8b-opt is unusable.** 5 timeouts at 180s + 1 wrong tool. The "purpose-built for OpenClaw" community fine-tune is incompatible with WireClaw's wire format. Cautionary tale.

## Future custom-bake exploration (deferred)

If/when we want to close the 1-test accuracy gap on llama3.1:8b or add personality/safety layers (SOUL.md style), the natural next experiment is to apply the SAP Modelfile recipe to llama3.1:8b instead of qwen3:8b.

Hypothesized result: `agent-llama:v1` (working name) baked from llama3.1:8b would inherit:
- Llama 3.1's faster per-token speed (~3s response time)
- The behavioral reinforcement that took opengates-agent:v1 from 18/22 → 20/22 over stock qwen3:8b
- Optional embedded personality/safety prompts via Modelfile

This would be the **power-user path** — documented but not the headline. Most users use stock `llama3.1:8b`. Power users who want the last 1-2 percentage points or want SOUL-style baking find this recipe in the docs.

The community-facing argument is: SOUL.md ideas can be tested and adopted as **system-prompt text** (in `data/system_prompt.txt`) without requiring custom weights. If others disagree with a specific SOUL formulation, they edit a file rather than retraining a model. Lower friction = better adoption surface for the underlying ideas.

Defer this until: (a) the chip is alive and the headline path is proven end-to-end, and (b) we've measured what specific competence gaps remain after firmware patches are applied.

## Project Opengates / SOUL.md constitutional framework

The WireClaw work sits inside a larger project called **Project Opengates** — Scott's broader effort to build aligned AI agents and robots governed by a model-agnostic constitutional framework called **SOUL.md** (25 articles covering truth-telling, non-weaponization, human dignity, privacy, political neutrality, AI transparency, a five-tier physical action authorization scheme, and operational transparency, among others).

**Published canonical version:** [https://www.clawhub.ai/souls/opengates-constitution](https://www.clawhub.ai/souls/opengates-constitution) (v0.2.0). The `www.` prefix is required — the bare `clawhub.ai` domain doesn't resolve correctly. About 26 KB / ~6,500 tokens of prose-formatted constitution written for human readers and cloud models with generous context windows. Has been carried unchanged across Claude Opus, Claude Sonnet, DeepSeek V3.2, and local Qwen variants — by design, model-agnostic.

**Compression tiers** (driven by edge deployment context budget; the trigger was moving off cloud LLMs to local 8B models on 8 GB GPUs, where practical context drops from 128K+ to ~16K usable, and the full SOUL.md was eating nearly half the budget before the agent said hello):

1. **SOUL.md (full):** ~6,500 tokens. Canonical, cloud-class. Above URL.
2. **SOUL-LOCAL.md:** Faithful distillation of all 25 articles for edge deployment. Same article numbers, same prohibitions, same duties — preamble prose, redundant appendices, version history, and markdown ornamentation cut. Principle: compress the document, not the ethics. Every prohibition in the original remained a prohibition in the distilled version.
3. **487-token system prompt baked into `opengates-agent:v1`:** Carries core articles (1-5, 7, 10, 15, 16) + identity + worked GPIO examples. The Modelfile-bake breakthrough that passed all four pillars (identity, tool calling, ethical refusal, honesty) on qwen3:8b. The working machine-readable form today.

**In progress (third track):** Structured JSON skill schema for the recursive learning architecture, where each skill carries its constitutional notes (relevant articles, authorization level, escalation triggers) as parseable fields rather than prose. That's where "machine-readable" stops meaning "shorter text" and starts meaning "structured data the framework can reason about programmatically." It's the foundation for the build-test-promote pipeline that lets new skills get added without ever touching the constitutional layer.

**Implications for WireClaw work** (currently deferred, but worth flagging):

- WireClaw's stock `data/system_prompt.txt` is generic helpful-assistant framing — no SOUL coverage. Any SOUL integration on the chip is future work, not part of the current patch set.
- The five-tier physical action authorization scheme matters more as we add actuators beyond LED. Toggling an LED is tier-1 trivial; engaging a relay that drives a heater or pump is higher-tier and should require corresponding authorization in the rule engine.
- The structured-JSON skill schema (third track above) has natural overlap with WireClaw's tool registry. If/when the third track stabilizes, WireClaw tool definitions could carry constitutional metadata in the same schema — making SOUL coverage a property of each tool rather than just the system prompt.
- Abliterated models (huihui_ai/* variants on mother brain) are a clean experimental substrate for testing whether a SOUL system prompt actually adds safety behavior, vs the model inheriting it from RLHF. Test queued for future session.

**Critical integration finding — Modelfile SYSTEM is bypassed by WireClaw.** The opengates-agent:v1 Modelfile bakes SOUL-LOCAL content into the `SYSTEM """..."""` directive. But Ollama's `/v1/chat/completions` follows OpenAI-compat behavior: an API-supplied system message in `messages` **replaces** the Modelfile's SYSTEM directive. WireClaw always sends its own `data/system_prompt.txt` content as a system message, so the SOUL-LOCAL bake is silently overridden. Same for Modelfile PARAMETER directives (temperature, num_ctx, stop) — WireClaw hardcodes these in the request body, overriding the bake. Net result: when accessed through WireClaw, only the Modelfile's `FROM qwen3:8b` line actually applies. opengates-agent:v1 and qwen3:8b are functionally identical from WireClaw's perspective. The 1-test bench delta between them (20/22 vs 19/22) is most likely random variance at temperature=0.7 stochasticity, not a SOUL-bake effect.

**Architectural consequence:** SOUL integration on the chip must happen via WireClaw's `data/system_prompt.txt`, not via Modelfile baking. Three viable approaches when the time comes:
1. **Two-tier prompt** — WireClaw essentials compact (~3000 chars) + SOUL-LOCAL appended (~3000 chars). Total ~6000 chars. Requires growing `cfg_system_prompt` buffer (similar to original P02 framing but redesigned).
2. **SOUL injected via memory channel** — repurpose WireClaw's existing `/memory.txt` system-message injection for constitutional content rather than user memory. Loses user-memory feature for SOUL coverage.
3. **Phase 2 LoRA** — get to constitution-in-weights, doesn't consume context. The long-term right answer per the recursive learning architecture, but requires curated training data from Phase 1 conversation logs first.

The **P02 redesign session** should explicitly leave structured budget for SOUL-LOCAL integration via approach 1 if SOUL is desired on chip. If SOUL is not in scope for first deployment, the compact rewrite stays at ~4000 chars and SOUL gets layered in later.

**Why this matters for upstream WireClaw:** any SOUL integration patches are clearly fork-only territory — Mario's WireClaw is a generic AI-agent framework, not a constitutional-AI platform. SOUL would be a WhitneyDesignLabs-specific extension. Don't confuse Mario by upstreaming anything from this layer.

## Infrastructure inventory

**Local LLM server:** mother brain = `azza.tail63f48.ts.net` (Tailscale MagicDNS, also `192.168.1.60` LAN and `100.65.170.13` tailnet IP). Username `azza`. GTX 1080 8GB VRAM. Ollama running on `:11434`. Open WebUI on `:3000`. Available models (May 2026): full list of 16 in `bench/results/run-*.md` headers; primary picks for WireClaw are `llama3.1:8b` (recommended) and `opengates-agent:v1` (backup).

**Workstation:** Windows 10 with WSL Ubuntu (`scott@DESKTOP-V1LNU1N`). Claude Code installed. Tailscale connected. SSH keys in `C:\Users\homet\.ssh\` for direct access to mother brain. `gh` CLI v2.87.3 authenticated as WhitneyDesignLabs account in WSL (HTTPS protocol, scopes `gist read:org repo`).

**Cowork workspace folder:** `C:\Users\homet\Documents\WireClaw\` (this folder, also at `/mnt/c/Users/homet/Documents/WireClaw/` from WSL). Persistent across sessions. Cowork can read+write; Claude Code (other tab/instance) can also read+write to coordinate.

**Local fork working tree:** `C:\Users\homet\Documents\WireClaw-fork\` (also at `/mnt/c/Users/homet/Documents/WireClaw-fork/` from WSL). Cloned from `WhitneyDesignLabs/WireClaw` with `M64GitHub/WireClaw` added as upstream remote. Ready for branch-and-patch workflow per `bench/fork/HANDOFF.md`.

## Repository layout

```
C:\Users\homet\Documents\WireClaw\
├── PROJECT_STATUS.md          # this file
├── Secrets.txt                # API keys (NEVER commit, NEVER read without asking)
└── bench\                     # Python tool-calling bench
    ├── README.md              # bench usage
    ├── run.py classify.py report.py    # the harness
    ├── test_cases.yaml        # 22 test cases
    ├── requirements.txt
    ├── wireclaw_data\         # WireClaw artifacts extracted from source
    │   ├── system_prompt_full.txt          # 7266-byte shipped prompt
    │   ├── system_prompt_truncated.txt     # 4095-byte what-the-chip-sees
    │   ├── tools_stock.json                # 20 tools as shipped
    │   ├── tools_examples.json             # augmented variant (P03 — see redesign note)
    │   └── build_examples_tools.py
    ├── results\               # bench outputs (one JSON+MD per run)
    │   ├── run-20260511T163604Z.{json,md}    # calibration: opengates-agent:v1 alone
    │   ├── run-20260511T170249Z.{json,md}    # 5-model existing-library bench
    │   ├── run-20260511T181908Z.{json,md}    # 5-model new-candidates bench
    │   ├── llama-full-examples.{json,md}     # variant: llama3.1 full+examples
    │   └── opengates-full-examples.{json,md} # variant: opengates full+examples
    └── fork\                  # firmware modification plan
        ├── PATCHES.md         # ordering, bucketing, etiquette (NOTE: P02/P03 need redesign)
        ├── HANDOFF.md         # shipping mechanics (gh CLI workflow)
        └── patches\
            ├── P01-text-leak-detector.md
            ├── P02-prompt-truncation-fix.md      # SUPERSEDED — see redesign note
            ├── P03-example-augmented-tools.md    # SUPERSEDED — see redesign note
            ├── P04-led-vocab-disambiguation.md
            ├── P05-serial-send-description.md
            ├── P06-config-wiring.md
            └── F01-ollama-defensive-opts.md

C:\Users\homet\Documents\WireClaw-fork\          # actual git working tree (cloned from WhitneyDesignLabs/WireClaw)
```

The WireClaw source tree itself is also cloned at `/tmp/WireClaw` inside the Cowork bash sandbox (ephemeral). To re-clone fresh: `git clone --depth 1 https://github.com/M64GitHub/WireClaw.git`.

## Patch shipping plan (revised)

### Patches that ship as drafted

- **P01** — Text-leak detector in response parser. Pure parser hardening, independent of prompt/tools choices. **Upstream PR candidate.**
- **P04** — LED vocabulary disambiguation in system prompt. Targeted rewrite, no expansion. **Upstream PR candidate.**
- **P05** — `serial_send` description fix. One-line tweak. **Upstream PR candidate. Best first PR — friendliest contact.**
- **P06** — Wire up unused `max_tokens` and `temperature` config fields. Mechanical, no behavioral risk. **Upstream PR candidate.**
- **F01** — Ollama defensive options (`stream:false`, `num_ctx`, `keep_alive`). **Fork-only.**

### Patches that need redesign

- **P02 — Original "grow the buffer to 8192" framing was WRONG.** Bench evidence shows growing the prompt context catastrophically hurts small models. The correct patch is: **rewrite `data/system_prompt.txt` to ≤4000 characters** while including compressed coverage of `chain_create`, time-based rules, and rule management. Targeted compaction, not expansion. This is design work — write a draft, run the bench against it, iterate. Probably a 1-hour focused session. Likely fork-only (Mario's prompt is fine for cloud models; this is local-LLM specific). May not need to grow the firmware buffer at all.

- **P03 — Original "augment all 20 tool descriptions with examples" framing was WRONG.** Bench evidence shows the larger tools JSON pushes small models into Mode D (drown) and cross-pollinates tool selection cues, producing WRONG_TOOL spikes. The correct patch is: **selective augmentation only for tools where Mode B was empirically observed in the baseline** (likely `file_write` for memory notes, `device_register` for NATS subjects). The other 18 tools stay terse. Bench against any candidate change before committing. Fork-only.

### Suggested first-PR sequence (unchanged from original plan)

1. P05 (smallest, friendliest first contact)
2. P01 (highest value)
3. P04 (small prompt-rewrite, low risk)
4. P06 (mechanical config fix)
5. P02-redesign (offer compact-prompt rewrite if Mario is interested)
6. P03-redesign (offer selective augmentation if Mario is interested)

Don't open all six at once — one issue + one PR at a time, breathing room between each, watch Mario's response style and pace.

## Day 1 hardware results (2026-05-11)

Board 1 flashed and validated end-to-end. Three independent paths proven:

**Vanilla cloud LLM path** (google/gemini-2.5-flash via OpenRouter):
- Read tool: "What is the chip temperature?" → 33.0°C ✓
- Off-domain refusal: "Who was the first US president?" → "I do not have access to general knowledge" ✓
- Self-knowledge bound: "What is your serial number?" → declined, listed actual capabilities ✓
- Info tool: "What is your IP address?" → 192.168.1.27 ✓
- Memory write: "My name is Scott / favorite color is purple" → file_write to /memory.txt ✓
- **Multi-step compound action:** "Set the LED to Scott's favorite color" → memory recall + RGB mapping + led_set + visible purple LED ✓
- **Persistent memory across power cycle:** unplugged USB, replugged into wall wart PSU (no host computer), sent same compound command, LED went purple again — confirming memory is in flash, not RAM ✓

**Local Ollama path** (llama3.1:8b via 192.168.1.60:11434):
- Same three tests after web-config swap (no reflash): all pass ✓
- Memory persisted across the model swap ✓
- Behavioral note: llama3.1 is chattier than Gemini ("I've called the tool `temperature_read`...") but factually correct
- Latency feel: comparable to cloud; LAN saves ~200ms RTT but llama's per-token cost adds it back
- Llama uses `device_info` more eagerly than Gemini did — when asked for serial number, called the tool, returned "ESP32-C6 rev 2" with helpful explanation

**LED status indicator (undocumented behavior, captured for reference):**
- Green heartbeat blip = idle/ready
- Blue = incoming Telegram message received
- Green during response prep = AI processing in progress
- Brief dark, then back to green heartbeat = response sent, returning to idle
- Application-level commands (like "Set LED red") override the heartbeat indicator
- Useful diagnostic without serial monitor

**Vanilla v0.4.0 minor issues observed (candidates for future patches):**
- Boot-time `[E][STA.cpp:530] disconnect(): STA disconnect failed! 0x3001: ESP_ERR_WIFI_NOT_INIT` is benign noise from defensive WiFi reset before init. Worth wrapping in `if (wifi_initialized)` to silence the false alarm.
- Windows captive portal hijacked us to msn.com instead of opening the WireClaw setup page. Manual `http://192.168.4.1` worked. May be a captive-portal-detection probe response WireClaw could improve.
- Telegram error surface is too generic. When the chip's LLM call fails, Telegram gets `[error: LLM call failed]` while serial shows the specific cause (e.g., `model 'X' not found`). Cost us 30+ minutes of guessing during the cloud-Gemini diagnostic detour. Worth a follow-on patch (call it P07) to surface the verbose error in Telegram.

## Patched firmware regression — isolated to P04 (2026-05-11 evening)

After Day 1 success on vanilla, we built `sap-fork-trunk` (P05+P04+P06+P01 merged) and flashed it. End-to-end chain still worked (Telegram round-trip, tool selection, execution, LED actuation). Initial smoke tests showed two apparent regressions vs vanilla; **subsequent investigation isolated one as patch-caused (P04) and the other as a separate, independent phenomenon (history reinforcement) that was always present**.

### Confirmed patch-caused regression: color-name-to-RGB reasoning for non-primary colors

- **Vanilla + llama3.1:8b**: "Set LED to my favorite color" (memory: purple) → model emitted `r=128, g=0, b=128` (correct purple). LED actually rendered purple. Visually verified.
- **Patched + llama3.1:8b**: same prompt → model emitted `r=0, g=128, b=255` (cyan-blue, not purple). LED rendered cyan.
- **Patched + "Set LED to red"** still works correctly (LED goes red). So the chip's tool execution is fine — it's the model's color reasoning that degraded.

**Root cause: P04 expanded the system prompt past the truncation threshold.** Vanilla's LED rules section was 3 lines (~250 chars). P04 rewrote it to ~9 lines with examples (~700 chars). The chip's `cfg_system_prompt` buffer truncates at 4095 chars. P04's expansion pushed roughly 700 chars of *other* content past the cut point — likely the Telegram-alert formatting guidance and parts of the NATS sensors / serial text sections. The model has clearer LED schema disambiguation now (P04's intent achieved), but lost context that previously helped it reason holistically about colors.

This is the **"ruthless compaction wins" finding reasserting itself one level deeper.** Even an isolated, well-justified prompt improvement can degrade overall behavior if it pushes other context out of the budget. P04 passes its own narrow test (T02 LED-off no longer fails on three models) but creates broader regression in stack with the existing 4095-byte truncation.

### Independent phenomenon (NOT patch-caused): history-induced response-format reinforcement

Initially we observed patched firmware giving raw tool output (`("result": "ok")`) instead of natural language ("The onboard LED is now red"). After reverting to vanilla, the same raw-output style PERSISTED on vanilla — disproving the hypothesis that patches caused it.

The actual cause: WireClaw keeps a 4-turn circular history in `/history.json`. The patched firmware's earlier raw-output responses got cached there, and the model was mirroring its recent past responses regardless of which firmware was running. **Verified by the `/clear` command test**: clearing history on vanilla immediately restored natural-language responses ("I called `temperature_read()` to get the current chip temperature, which is 28.0 C"). Same model, same firmware, only difference was a clean history.

Implication: history reinforcement is a real and measurable behavior amplifier. It can lock the model into degraded patterns across firmware swaps and even model swaps. **Worth filing as a future fork patch candidate**: surface a "history quality" warning when the model's recent responses look anomalous (raw JSON, missing tool calls, etc.), or expose a one-tap "clear history" via Telegram command (it currently exists as `/clear` per the `/help` output but isn't documented).

### Independent finding: prompt clarity matters disproportionately for small models

During the 8:42-8:45 PM vanilla retest, Scott observed that natural-language convoluted prompts ("Make the LED as such, his color" / "Make the LED Scotts favorite color") produced model confusion, hallucination, and naked-JSON-in-prose leaks. The same intent expressed simply ("Set the LED to Scotts favorite color.") executed cleanly with correct purple. **Reproduced from first principles a well-known prompt-engineering finding**: small models reward direct imperative phrasing and punish ambiguity. Worth documenting in any future user-facing docs ("Talk to your WireClaw like you'd ask a 5-year-old to do something — direct, unambiguous, single-action commands").

### P01 detector gap empirically confirmed

The 8:45 PM "But the LED is not illuminated. Try again." response produced a naked-JSON leak: `{"name": "led_set", "parameters": {"r": 128, "g": 0, "b": 128}}` in the content body, no structured tool_calls. **P01's current detector pattern set would not catch this** because it's not fenced (no ```` ```json ` markers), not XML-wrapped (no `<tool_call>` tags), and not in tool_name(args) call syntax. Adds empirical pressure to expand P01's pattern set per task #16's investigation. Specifically need: a regex matching JSON objects containing `"name"` and `"parameters"` keys.

### Current chip state and fork branches

- **Chip:** reverted to vanilla v0.4.0 via PIO build+flash from `main` branch. Verified end-to-end working with local Ollama llama3.1:8b. LittleFS data partition (config.json, memory.txt, history.json) preserved through all the reflash cycles.
- **Fork branches:** `main` is upstream-clean. `sap-fork-trunk` has the four patches merged (P05+P04+P06+P01). Local working tree on `sap-fork-trunk` so the patched code is the next-session starting point.
- **Patches awaiting work:** P04 needs redesign (task #14); P02 needs the compact-prompt rewrite that combines well with P04v2 (task #11); P06 needs a UI form follow-up to expose temperature/max_tokens (task #15); P01 needs detector pattern expansion (subset of task #16).

**Critical guardrail for upstream PRs:** do NOT submit P04 upstream as-is. Causes regression. Hold until redesigned. P05, P06, P01 are likely safe to upstream individually but bisection (task #16) should confirm before going public.

## Open questions for the next session

All Day 1 questions resolved. Remaining open items now tracked as tasks #9-13.

**Suggested next-session order:**

1. **Task #16** — Bisect which patch caused the response-formatting regression. Build P04-only, P05-only, P06-only, P01-only firmware variants and smoke-test each on llama3.1:8b. Confirm or refute the P04-is-the-culprit hypothesis. ~30 minutes.

2. **Task #14** — Redesign P04 to be net-shorter than vanilla's LED section. Once redesigned, build P04v2-only and verify no regression. Combined design session with task #11 makes sense.

3. **Task #11** — P02 redesign session. The compact-prompt rewrite covering chain_create + time-based rules in ≤4000 chars. Design alongside P04v2 so the total prompt budget works.

4. **Task #15** — Extend web config form to expose temperature and max_tokens fields (P06's UI gap). Trivial patch but unblocks per-deployment tuning.

5. **Task #5 follow-up** — Open upstream issues at M64GitHub/WireClaw. **Critical: do NOT submit P04 upstream as-is** — it causes a regression. Lead with P05 (still safe and trivial) as the friendliest first contact.

6. **Task #12** — Apply F01 (Ollama defensive opts) and measure cold-start vs keep_alive impact. Documented win for the headline config.

7. **Task #13** — Tailscale Funnel or Cloudflare Tunnel setup for road use. Once standing, the chip's API Base URL changes to the public endpoint and the smoke tests re-run from any network.

**Future strategic explorations** (low priority, defer until above are done):
- Custom bake on llama3.1:8b base (`agent-llama:v1` recipe)
- F02 XML `<tool_call>` parser branch (only if Hermes-class candidates become interesting)
- F03 Zigbee end-device support (now scoped — the C6 is on the desk)
- F04 MCP server endpoint exposing chip as MCP target (also now scoped)
- P07 verbose error surfacing to Telegram (would have saved 30 min during cloud-Gemini diagnostic detour)

## Reference context

- **Scott's Project Opengates context primer** (May 2026 chat-history paste): the deepest source for the failure-mode taxonomy (Modes A-E), SAP-era findings, Modelfile-bake recipe, and "examples beat instructions for small models" insight (now refined: examples beat instructions *when the model has context budget for them*; below that threshold, terse wins). Treat as authoritative source-of-record for those decisions.
- **WireClaw audit findings**: embedded in `bench/fork/PATCHES.md` (problem statements per patch).
- **Berkeley Function Calling Leaderboard V4**: `https://gorilla.cs.berkeley.edu/leaderboard.html` — current authoritative function-calling benchmark for model selection.
- **The `voytas26` model is a cautionary tale**: Don't pull "purpose-built for X" community fine-tunes without first running them against the WireClaw wire format. Mode-C / timeout / format-mismatch killed it.
- **The prompt-expansion experiment is a cautionary tale**: Don't apply the "obvious fix" to a small-model context-budget situation without measuring. Sometimes the bug is doing useful work.

## Credentials and secrets — DO NOT commit

- OpenRouter API key (full value not stored in this repo; lives in `Secrets.txt` at workspace root)
- Telegram bot token (full value not stored in this repo; lives in `Secrets.txt`)
- SSH keys for mother brain (in `C:\Users\homet\.ssh\`, never paste)

The `bench/` directory has no secrets. Safe to push to a GitHub fork.

The `data/config.json` file on a flashed ESP32 will contain the OpenRouter API key and Telegram bot token. **Do NOT commit your filled-in `config.json` to the fork.** Mario already provides `config.json.example` files — keep using those and let the chip's web portal handle real values.

`Secrets.txt` is at the workspace root and contains real API key values. Add `Secrets.txt` to `.gitignore` if any directory containing it ever becomes a git working tree.
