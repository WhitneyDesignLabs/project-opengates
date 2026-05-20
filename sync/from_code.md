# Code Handback — Phase 4.1.1 SALVAGE COMPLETE + 4.1.2 begun — 2026-05-19 midday

## Status: ✅ Path A salvage executed. Repaired corpus written; quality lift is decisive. Phase 4.1.2 housekeeping now in flight (Step 1 PROJECT_STATUS.md rewrite next).

### §1.3 SALVAGE (Path A) — DONE
- Pulled 8,544 in-window proxy records from azza → `corpus/proxy-4.1.1/files/` (4,463 c6-02/.15 + 4,081 c6-03/.47). Single tar over Tailscale (~4 MB).
- Driver `phase_4_1_1_salvage.py` imports `merge_corpus`'s pairing functions, walks 303 user-side sessions, filters records to (client_ip + ts window), calls `merge_records_into_turns` → emits `bench/fork/lora/corpus/v1.1-overnight-2026-05-18.REPAIRED.jsonl`.
- **8,542 records consumed (2 boundary stragglers; negligible). 3,548 repaired turns.** (More than the 3,030 scrambled — proxy-side turn detection picks up turns the Telegram-side recorded as single units.)
- **Objective on-topic — strong PASS:** temp 14.5%→**83.0%** (6×); led 11.0%→**78.1%** (7×); ip 4.5%→**88.5%** (20×). Pairing is request/response-anchored, not stream-ordered. 92.5% of turns have a non-empty `wrap_up_text`.
- Persona-id fuzzy-match attached to 521/3,548 turns — low, but `merge_corpus.match_prompt_to_persona` uses substring matching that struggles with the proxy-side request-text shape (system-prompt prepended). Metadata only — does NOT affect pairing correctness. Re-tunable; not blocking.
- Output schema: richer than the user-side JSONL (`prompt`, `wrap_up_text`, `tool_calls_fired`, `tool_results`, `messages_sent_to_llm_iter1`) — useful for training tool-use traces.

### Phase 4.1.2 housekeeping (in progress)
- **Step 1 PROJECT_STATUS.md rewrite — DONE.** Top "Current state pointer" + new "Recent phases (4.0.x → 4.1.x)" section + "Known v1.1 residuals" + "Queued work" prepended; historical bisect-era content from line ~14 preserved unchanged.
- **Step 2 git audit — BLOCKED.** Directive says "Scott has initialized the git repo + remote at the workspace root" but on-disk reality: **no `.git/` directory** exists at `C:\Users\homet\Documents\WireClaw\` (`git rev-parse` → exit 128; `ls -la` shows no `.git`). Not auto-initing per prior directive's gating language. Scott decision: init repo + remote yourself, or authorize Code to `git init` + set remote.
- Step 3 milestone commit, Step 4 push, Steps 7-8 (gated) — queued behind Step 2 repo existing.

- **Step 5 WireClaw-fork audit — DONE.** `bf80fa9` confirmed at tip of `origin/wdl-v1`; local branch up-to-date. **However:** 5 files have uncommitted local changes — `data/system_prompt.txt`, `include/llm_client.h`, `src/llm_client.cpp`, `src/main.cpp`, `src/tools.cpp`. These were NOT in yesterday's "uncommitted" set (which was tools.cpp / main.cpp / rules.cpp, all of which landed in bf80fa9). So these are *newer* edits since bf80fa9. **Not touching them autonomously — flagging for Scott.** Probably in-progress firmware work; review/commit/discard at his discretion.
- **Step 5 bonus — P05 upstream issue #12:** OPEN, **0 comments, no activity since 2026-05-12 23:26 UTC** (7 days). Mario has not responded. PR remains gated per `bench/fork/PATCHES.md` etiquette. No change in posture.
- **Step 6 HF model release prep — DONE (prep only, upload gated).**
  - **Adapter located:** `bench/fork/lora/training/output/wireclaw-v1-adapter.tar.gz` (65 MB compressed). Contains `wireclaw-v1-brev/` with `adapter_model.safetensors` (84 MB), `adapter_config.json`, `tokenizer.json` + `tokenizer_config.json`, `chat_template.jinja`, `training-log.json` (per-epoch loss: 0.026 → 0.026 → 0.015), `training-config.yaml` (LoRA r=16/α=32, all-linear targets, 3 ep, bs=8, lr=2e-4 cosine, warmup_ratio=0.03, max_seq=3072, bf16, sdpa). No GGUF in the tarball — that conversion lives in the Modelfile-based path on azza; can be regenerated for HF if needed (or HF can serve safetensors directly).
  - **Model card drafted:** `bench/fork/lora/hf-publish/README.md` — full HF-format card with Llama 3.1 license + "Built with Llama" attribution, training procedure table, loss curve, training-data summary (curated tool-use + synthetic constitutional + memory-chain), intended/out-of-scope use (citing SOUL.md Part II + Article 19), constitution links (SOUL.md / SOUL-LOCAL.md / SOUL-CHIP.md), performance (303 sessions / 3030 turns / 1 banner / 42-of-42 emergency_stop), known limitations (indirect-reference LED, reasoning-trace leak, ~5% pseudo-prose), PEFT + Ollama usage snippets, BibTeX citation.
  - **What Scott needs before Step 7 upload can fire:**
    1. **HF account** — suggested `WhitneyDesignLabs` org (or personal `scottwhitney7` if no org).
    2. **HF API token with write scope** — https://huggingface.co/settings/tokens.
    3. **HF repo name** — recommended `whitneydesignlabs/wireclaw-agent-v1.1-lora` (or substitute the chosen account/org).
    4. **Llama 3.1 base-model license acceptance** on HF — one-click at https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct (required for derivative publication).
    5. *Optional:* a `<YOUR-HF-USER>` substitution in the model card draft will fire once the repo name is fixed.

---

# Code Handback — Phase 4.1.0 Step 7 + Phase 4.1.1 §1.2 — 2026-05-19 morning

## Status: ⏸️ GATE. Step 7 BLOCKED (workspace is not a git repo — not auto-initing per directive). Phase 4.1.1 §1.2 bug localization DONE — root cause confirmed in code, fix sketched, NOT applied (awaiting Scott review per §1.2b). §1.1 azza probe still hung in background (Tailscale) — will append when it returns.

### Step 7 — BLOCKED: workspace is not a git repo
`git rev-parse --is-inside-work-tree` → exit 128, `NOT-A-GIT-REPO`. No `.git` at `C:\Users\homet\Documents\WireClaw`. Per directive ("do not git init autonomously") I stopped Step 7. **Scott decision needed:** init the workspace repo + set remote yourself, or authorize Code to `git init`. The commit message + file scope from the directive are ready to execute the moment a repo exists.
- **Protective sub-action recommended (gated):** the quarantine move of the scrambled corpus is part of Step 7 but is independent of git and protects against accidental training on bad data. Recommend doing it now regardless: `bench/fork/lora/corpus/v1.1-overnight-2026-05-18.jsonl` → `corpus/quarantine/v1.1-overnight-2026-05-18.SCRAMBLED.jsonl` + README. Holding on Scott's word since the directive said "stop here."

### Phase 4.1.1 §1.2 — bug localization (root cause CONFIRMED)

**PRIMARY ROOT CAUSE — `persona_runner.py`, confidence HIGH.** Exactly the directive's top hypothesis.
- `_on_reply` handler (lines 162–164): enqueues **every** message from the bot into one FIFO `reply_queue` — zero correlation (no `reply_to_message_id`, no content match).
- `send_and_await` (lines 166–179): a pre-send drain (168–172) discards whatever is in the queue *at send time*, then `reply_queue.get()` (line 176) pops the **first subsequent message** and treats it as the reply.
- Mechanism: the WireClaw chip emits **multiple** Telegram messages per prompt (intermediate `[Agent] N tool call(s)` lines + the wrap-up), **plus** unsolicited self-firing-rule messages (`heater_reminder`/`temp_alert` every 5 min / 5 s — the ones we cleared this morning), **plus** `/clear`→"History cleared" bookend echoes. Pop-first matches prompt N to whichever stray message surfaces first. The pre-send drain only removes already-arrived messages; with chip latency 8–25 s vs `DEFAULT_INTERACTION_DELAY_S`=6 s, real replies routinely arrive *after* the drain and mispair.
- Quantitative fit (explains all of it): ~14% on-topic (first arrival occasionally correct), 74.6% scrambled-not-fixed-lag (variable stray-msg count per turn — unrepairable by a shift), 16.5% literal "History cleared" (the `/clear` echoes + history-clear side-effects flooding the FIFO).

**SECONDARY AMPLIFIER — RETRACTED after on-Pi verification.** Earlier I flagged `overnight_capture.sh` line 42 `RULE_PURGE_URL` defaulting to `.19` (pilot) as an amplifier. **This is false for production.** The *workspace* copy of `overnight_capture.sh` is a stale evobot/pilot variant (BOT_USERNAME=wdl_c6_pilot_bot, RULE_PURGE_URL→.19). The **deployed** pi02 copy is per-Pi correct: line 39 `RULE_PURGE_URL="http://192.168.1.15/api/rules/delete"` (c6-02), line 47 `BOT_USERNAME=wdl_c6_02_bot`, line 48 `SESSION_FILE=~/.telethon-pi02.session`. Rule-purge hit the correct chip every session. Rule accumulation is fully explained by personas creating rules *mid-session* (purge is session-START only, so intra-session rules persist + fire) — no purge-target bug. **Net: there is ONE root cause — the `persona_runner.py` uncorrelated FIFO. No phantom, no purge-IP amplifier.**

**NOT THE BUG — `merge_corpus.py`, confidence HIGH (and this is the salvage key).** It pairs prompt→reply from the **azza proxy request/response structure** (request.messages ending user-role = new turn; response.content = wrap-up) — deterministic, content-anchored, independent of Telegram ordering. The scrambled corpus is the `persona_runner.py` *user-side* JSONL (stream 1); the code's own docstring says the **canonical corpus is the azza proxy (stream 3)**, which `merge_corpus.py` pairs correctly. **→ §1.3 Path A (salvage from azza) is well-supported by existing code, contingent only on §1.1 proxy coverage.**

### Proposed fix sketch (NOT applied — gated on Scott review, §1.2b)
- `persona_runner.py`: replace pop-first FIFO with **correlation + quiescence**. Capture sent `Message.id`; collect all bot msgs after ts_sent; close the turn after ~5 s of no new bot msg (settle) or timeout; reply_text = last substantive msg, filtering plumbing (`History cleared`, `WireClaw v… started`/`Config:`/`mDNS:`, `[Agent] … tool call(s)`, unsolicited rule-fires); pace next prompt on settle, not a fixed 6 s. **Best variant:** if WireClaw firmware sets Telegram `reply_to` on its wrap-up, match `event.message.reply_to.reply_to_msg_id == sent.id` exactly — needs a WireClaw-fork check; if absent, the settle approach is the harness-only fix.
- `overnight_capture.sh`: parameterize `RULE_PURGE_URL` per-Pi, fail LOUD (currently silent/non-fatal) if purge target unreachable, purge at session END too; verify deployed copies on pi02/pi03.

### §1.2 hypothesis (0) — External phantom prompter: CONCLUSIVELY RULED OUT
Scott's live theory (old evobot Pi running stale code = phantom) tested against all directive-(0) candidates:
- **evobot .51:** powered + booted but NO `persona_runner`/`overnight_capture`/`telethon` process; `.telethon-evobot.session` stale (May 17 07:01); last capture-log line "overnight capture END … Sun 17 May 07:02:26 MST 2026". Idle 2 days. NOT the phantom.
- **k-scale-trainer:** unreachable LAN .39 + Tailscale → powered off. Cannot be the phantom.
- **pi02/pi03/azza:** already clean (4.0.4a sweep, no sender procs).
- **CHIP-SIDE from_id (the decisive test):** c6-02 serial logs `[TG] Message from 8430366600: …` for every incoming message. `8430366600` = Scott's account (directive L109) = persona_runner's own Telethon identity. **Zero foreign from_id.** No second prompt source exists.

**Verdict: (0) is false. No phantom. The root cause remains the `persona_runner.py` uncorrelated-FIFO bug (§1.2 PRIMARY, confirmed in code).** Scott's 7:01–7:04 MST observation = the overnight run's OWN backlog draining: persona_runner fired ~3,600+ Telegram msgs over 11 h; the chip processes them serially ~15 s each (offset-persist ⇒ none dropped) ⇒ ~15 h backlog tail. At 07:2x c6-02 was still HTTP-busy and serial-confirmed processing a persona_04 overnight prompt ("What names did I save to memory?"). Rules churn (create/delete) as backlog prompts flow ⇒ this morning's one-time rule-clear could not quiet it.

**Remediation note (gated recommendation):** to actually silence the fleet, the **Telegram update backlog must be nuked server-side** (`phase_4_0_3_tgnuke.sh`/`tgflush.sh`), not just rules cleared. Backlog = already-captured overnight prompts, safe to drop (corpus is on the Pis). L2 — recommend, gate on Scott.

### Actions executed this session (Scott-authorized via 4-question gate)
1. **TG backlog nuke — DONE.** New `phase_4_1_1_tgnuke.sh` flushed the TWO real fleet bots (`wdl_c6_02_bot` 8467…, `wdl_c6_03_bot` 8996…) — the old `phase_4_0_3_tgnuke.sh` only hit `wireclawsap_bot` 8700… (wrong bot, why the backlog persisted). `deleteWebhook?drop_pending_updates=true` ok on both; server pending=0. c6-02 verified drained (HTTP healthy uptime 13h30m, serial shows no Telegram/agent activity — only harmless ADC HAL-noise from an internal rule). Fleet quiet on Telegram.
2. **Quarantine — DONE.** `v1.1-overnight-2026-05-18.jsonl` → `corpus/quarantine/v1.1-overnight-2026-05-18.SCRAMBLED.jsonl` (3030 lines preserved), canonical path clear, `corpus/quarantine/README.md` written.
3. **§1.2b fix — APPLIED + DEPLOYED.** `persona_runner.py`: replaced pop-first FIFO with collect-all-until-quiescence (`SETTLE_S=5`) + `_is_substantive()` plumbing filter (drops "History cleared", boot banners, `[Agent]`/`[TG]` traces); reply = last substantive message; added `msgs_collected`/`msgs_substantive` diagnostics. py_compile OK locally + on-Pi. Deployed to pi02 (`~/wireclaw-phase31/...`), original backed up `persona_runner.py.bak-pre-4.1.1` (md5 0e28ce17→7dcc7130). No firmware change (tgSendMessage sets no reply_to → exact-correlation unavailable; settle is the harness-only fix).
4. **20-turn validation — DONE, FIX VALIDATED (strong pass + 1 residual).** Patched runner, persona_01_basic + persona_07_sensor_telemetry vs c6-02, 20 turns, 0 timeouts.
   - **On-topic: led 4/4=100% (was 11%), ip 1/1=100% (was 4.5%), temp 3/4=75% (was 14.5%).** Sample pairs now correctly aligned ("Set the LED to red."→"I've set the LED color to red."; "What is your IP address?"→"My current IP address is 192.168.1.15."; "When chip temp >30…alert"→"rule is now active … Telegram alert whenever chip temp"). Effective pairing accuracy ≈ 95–100%.
   - The temp "miss" (1/4) is NOT a mispair: "What is the chip temperature?"→"Sorry, the model responded incorrectly. Please rephrase." — a genuine chip error-reply, *correctly paired*, just not containing "degrees". So it's a model/firmware quality artifact, not harness desync.
   - **Multi-message settle works:** msgs_collected min=1 max=3 avg=1.1; multi-msg turns settled correctly and picked the last substantive.
   - **RESIDUAL (one true mispair, known class):** the "diagnostic: read all input pins" turn collected 3 msgs and returned "Heater: check!" — an *unsolicited rule-fire* message (from the `heater_reminder` rule the persona itself created earlier in the same session) landed mid-settle-window. The plumbing filter intentionally doesn't drop rule-fire text (it's indistinguishable from a real answer by content). **The settle fix is robust to intermediate agent traces / /clear echoes / boot banners but NOT to unsolicited rule-fire messages arriving mid-window.** Mitigations: (a) rule-purge hygiene (don't let capture personas create Telegram-action rules, or purge mid-session); (b) the azza-proxy salvage path (Path A) is *immune* to this — proxy pairing is request/response-anchored, not Telegram-stream-ordered. For a future clean re-capture (Path B) the rule-fire residual must also be addressed (persona review or capture-mode rule suppression).

### §1.1 — azza proxy coverage: SALVAGE VIABLE (clean)
(Original background probe was a Tailscale zombie; relaunched with hard timeout — azza is up.)
- **8,544 in-window proxy records** (MST window 20260518T191100..20260519T060300), all `chat/completions`, **0 malformed**.
- Per client_ip: **c6-02/.15 = 4,463**, **c6-03/.47 = 4,081** — both chips fully represented.
- Window exact: first `20260518T191100` (19:11:00 = launch), last `20260519T060252` (06:02:52 = stop). Per-IP spans both run start→stop continuously.
- **Continuity: max inter-record gap 65 s, zero gaps >300 s, zero drop windows.**
- ~8,544 / 303 sessions ≈ 28 calls/session ≈ 2.8/turn (agentic tool loops) — consistent with ~3,030 turns. Proxy `ts` is MST-local compact `YYYYMMDDThhmmss_micros`; records carry `client_ip`,`path`,`request`,`response` — `merge_corpus.py` already pairs these deterministically.

### §1.3 — RECOMMENDATION: Path A (salvage from azza). Gated on Scott.
Coverage is full, continuous, clean for both chips across the entire run → the scrambled 3,030-turn corpus is **recoverable offline** from the proxy log via `merge_corpus.py`'s request/response-anchored pairing. **Path B (re-capture) is unnecessary** — the data exists intact on azza; only the Telegram-side pairing was lost. The persona_runner fix (validated ~95–100%) is still required for FUTURE captures but does not block salvage of this run. Path C (hybrid) not needed.
Proposed salvage steps (NOT executed — gated): pull the 8,544 in-window proxy records per chip → run `merge_corpus.py --proxy-logs <dir> --persona <p> --session-id …` per persona/session → reassemble a clean `v1.1-overnight-2026-05-18.RECOVERED.jsonl` → quality-probe it (expect on-topic ≫14%) → then it's labelable (Step 6(1) conditional) and a v1.3-training candidate (Step 6(3)).
Open question for salvage: `merge_corpus.py` takes one `--persona`/`--session-id`; the run is 303 sessions × 7 personas. Need a driver that maps each proxy record batch to its persona/session (by client_ip + ts window vs the persona rotation in `overnight_capture.sh`). Feasible (the rotation is deterministic: round-robin by session_count); will design it if Scott approves Path A.

### Held / next
- §1.3 salvage (Path A): recommended, **gated on Scott** — do not execute autonomously.
- §1.2b validation: result pending (background) → then recommend salvage Path A/B (§1.3), gated on Scott.
- Rule re-clear on c6-02/c6-03: NOT done (Scott chose "Nuke" over "Nuke+re-clear"); current rules act on GPIO/actuator not Telegram, so fleet is Telegram-quiet anyway. Recommend a re-clear before any future capture; gated.
- Step 7 commit: gated — Scott initializing the repo + remote himself; Code runs the prepared commit once it exists.
- No commit, no labeling/training/push, no salvage/re-capture — all gated.

---

# Code Handback — Phase 4.1.0 — Step 1 done + post-stop noise diagnosed — 2026-05-19 morning

## Status: ⏸️ GATE — Step 1 PASS (auto-stop fired cleanly, 4.0.1 bug fixed). Corpus is intact and finalized. The "Telegram still busy" noise is diagnosed and benign to the corpus, but the chips need a cleanup that is OUT of Step 1's pkill scope — proposing it below, holding for Scott's go before touching chip rule state or c6-01.

### Step 1 — auto-stop verdict: ✅ CLEAN on both production Pis
- **pi02 / c6-02:** no `overnight_capture.sh` / `persona_runner.py` procs (only the SSH self-match string). `.status.final`: `session_count=158 error_count=0 ended_at=2026-05-19T060123 stop_reason=stop-flag-file`. STOP_FLAG consumed on graceful exit.
- **pi03 / c6-03:** same — no procs. `.status.final`: `session_count=145 error_count=0 ended_at=2026-05-19T060249 stop_reason=stop-flag-file`.
- The detached `sleep → touch STOP_FLAG` watchdog **fired on both** (~06:01 / ~06:02 MST). This is the fix for the 4.0.1 auto-stop-didn't-fire finding — confirmed working. Combined **303 sessions, 0 errors**, clean stop. Corpus is safe to aggregate (Step 2).

### Why Telegram is still busy after the runner stopped (root cause, 3 sources)
1. **Telegram backlog drain tail.** `persona_runner` queued a pile of prompts before 06:01; the chip processes them serially at ~15 s/turn. New firmware persists tg-offset BEFORE processing (no infinite loop), so the backlog is finite and self-draining — but a long tail of varied chatter (memory read, LED, status) continues post-stop. This is the bulk of the c6-02 6:23–6:26 messages.
2. **Persona-created rules firing autonomously (the real spam engine).** The personas had the chips create rules that survive the runner. Confirmed on c6-03 `/api/rules`: `rule_01 heater_reminder` → telegram "Heater: check" **every 300 s**; `rule_02 temp_alert` → telegram "{value}C" **every 5 s** when chip_temp>30. c6-02 serial shows it created `rule_05 temp_warning` (and the 6:26 Telegram shows a heater_reminder on c6-02 too). These fire forever with no sender alive. c6-02 HTTP times out because it's single-threaded and pinned in 15 s LLM calls — it's alive (serial confirms live agent activity), not crashed.
3. **c6-01 pilot boot-loop.** The repeated `WireClaw v0.4.0 started / Config: http://192.168.1.19/` banner. c6-01 is the deferred Phase 4.0.5 chip, never reflashed with bf80fa9 — still on old firmware doing poison-redelivery boot-loop. .19 is unreachable (100% ping loss, HTTP dead) because it resets every few seconds. Only physical power-down or paired-Pi serial/JTAG stops it. **Scott action — physical/deferred chip.**

### Proposed cleanup (NOT executed — gated; out of Step 1's pkill-only scope)
- c6-02 + c6-03: `POST /api/rules/delete {"id":"all"}` (the established 4.0.3 recovery) to kill the self-firing persona rules. L1/L2, does NOT touch the finalized corpus.
- Optionally let the Telegram backlog self-drain (finite) or nuke the server-side queue if Scott wants it silent now.
- c6-01: Scott decision — power-down vs. leave (it's deferred, generates spam but no corpus).

### Cleanup EXECUTED (Scott approved 2026-05-19 morning)
- **c6-03:** `/api/rules` → `[]` (cleared, HTTP alive).
- **c6-02:** `phase_4_0_3_clearrules.sh` hammer → HIT attempt #2 `{"ok":true}`, verify `/api/rules` → `[]`, HTTP alive.
- Both production chips' rule stores now empty → self-firing persona-rule spam stopped. Telegram backlog left to self-drain (finite; offset-persist prevents loop) — Scott did NOT request server-side queue nuke.
- **c6-01:** Scott powering down physically (deferred Phase 4.0.5 chip). No Code action.

### Step 2 + 3a/3b — DONE
- Pulled `*overnight*.jsonl` from both Pis; user-side dir accumulates multi-run history back to 2026-05-15, so filtered to the 4.0.4a window (persona-suffixed + filename ts in [2026-05-18T1911, 2026-05-19T0700) MST). Windowed count matches `.status.final` exactly: pi02=158, pi03=145.
- Aggregated → `bench/fork/lora/corpus/v1.1-overnight-2026-05-18.jsonl`. c6-02 1580 turns / c6-03 1450 turns / **combined 3030, 0 dups**. Schema: `{ts_sent,ts_received,prompt_id,prompt_text,reply_text,reply_timed_out,elapsed_s}`, 10 prompts/session.
- Volume vs 4.0.1 (227 turns): ~13× (serial single-chip, not the 25–50× the directive estimated — run was throughput-bound, not error-bound). First real comparable-scale v1.1 corpus.
- Persona balance: even (200–230/persona/chip), all 7 present both chips. Early signal: mismatched replies present (e.g. "chip temperature?" → "History cleared") — same garbling as Scott's Telegram excerpt; quantifying in 3c/3d.
- Helper scripts: `phase_4_1_0_pull.sh`, `_inv.sh`, `_window.sh`, `_aggregate.py`.

### Step 3c/3d/4/5 — DONE — ⏸️ STOP AT STEP 6 GATE

**HEADLINE: the 3030-turn corpus is NOT trainable as captured — prompt↔reply pairs are scrambled.** Firmware/hardware validation, by contrast, is a clean decisive PASS. These are independent: the run proved the fix works; the capture harness mispaired the data.

#### Corpus quality — desync is the dominant finding (3c/3d + probe)
- Heuristic form-buckets looked okay (clean 70%, pseudo-prose 17%, error 10%, JSON-leak 2.4%) but form ≠ correctness. Objective content probe on self-checking prompt classes:
  - temperature-prompt → temperature-reply: **14.5%** (392 cases) — should be ~100%
  - LED-prompt → LED-reply: **11.0%**; IP-prompt → IP-reply: **4.5%**
- Lag test: aligned 13.9% / one-behind 11.5% / **neither (scrambled) 74.6%** — NOT a fixed offset (a fixed lag would be repairable by a shift); it's scrambled.
- **16.5% of all replies are the literal string "History cleared"** (a clear-history side-effect bleeding onto unrelated prompts). 493 history-cleared-mismatch instances.
- Root cause (high confidence): capture harness pairs Telegram replies to prompts by send-order while the chip processes asynchronously/backlogged — same mechanism as Scott's "Telegram still blabbing" excerpt. Haiku-labeling or training on this as-is = wasted spend.

#### Anomaly hunt (3d) — clean
- boot-banner-in-reply: **1** in 3030 (one c6-03 reset blip) — chips essentially did not crash-loop. identity-drift (Llama/Meta/"as an AI"): **0**. empty/timeout: **12** (0.4%, all c6-03, minor). tool-error: 10 — all graceful pin-guard rejections ("GPIO 25/12 is reserved"), zero crashes.

#### Step 4 — persona_06 (remapped pins) — decisive PASS (the real point of the run)
420 turns, 42 sessions per prompt_id. **p06_emergency_stop (yesterday's deterministic GPIO-25 fleet-killer): 42/42 ok, 0 errors, 0 resets, 0 boot-banners.** p05_park_sequence (multi-pin chain): 42/42, 0 resets. p08_spindle (GPIO 23, was 26): 42/42. p04_chain_endstop_alert: 41/42 (1 boot-banner — the lone corpus reset). The 4.0.3 three-fix firmware + persona pin-remap is **validated under 11h sustained load**: the deterministic crash trigger is dead. (Caveat: "ok" = survived/no-error; replies still desynced like the rest — survival is what Step 4 tests and it passed.)

#### Step 5 — cross-ref
- 4.0.1 morning corpus = 227 turns; tonight = 3030 (~13×) — but tonight's is desync-poisoned, so it is NOT yet the "first labelable comparable-scale v1.1 corpus" we hoped.
- 5b: `3.1.3-2026-05-16-c6-0{2,3}.haiku.json` did not parse with flat-list/`label` key assumptions — schema differs; baseline label distribution NOT extracted (needs a schema look — flagged, not blocking).
- Haiku cost estimate: ~$2–3 / 250 turns → ~$25–36 for 3030 turns. **Recommendation: do NOT spend it on the desynced corpus.**

#### Salvage path (azza ground truth) — probe in flight
The azza proxy log records the true model request/response pairing (proxy-side, not Telegram-order). If it covers 2026-05-18/19, the corpus is likely **re-pairable offline** from proxy timestamps instead of re-capturing. Probe running; result appended below before final gate handback.

#### Scott decision points for Step 6 gate
1. Corpus: re-pair from azza proxy (if coverage good) vs. re-capture with a fixed harness vs. abandon this corpus.
2. Capture harness: the prompt↔reply pairing bug must be fixed before any future run (queue/ack-order, not send-order). This is a new must-fix, sits alongside Phase 4.0.4.
3. Do NOT Haiku-label or train on the current corpus (recommend).
4. Firmware: the 3-fix + remap is validated — green light for the milestone commit (Step 7) on that basis if Scott wants.
5. c6-01 power-down (Scott physical) still pending.

NOT done autonomously (gated): no labeling spend, no training run, no git commit/push, no further persona/harness edits. Holding for Scott.

---

# Code Handback — Phase 4.0.4a COMPLETE — 2026-05-18 ~19:25 MST

## Status: ✅ All 5 steps done. Overnight capture LIVE on pi02+pi03, full 7-persona rotation, 0 errors, real corpus flowing, graceful 06:00 MST auto-stop armed. Firmware fixes committed+pushed (bf80fa9). Personas remapped off reserved pins. Scott clear to sleep.

### Step 1 — no external sender (Telegram queue-replay; fixed)
No sender procs on pi02/pi03/azza. Stale `.telethon-pi02/03.session` files dormant — **kept** (Scott: they're persona_runner's auth state; deleting forces interactive re-auth). No `/api/telegram` endpoint. c6-02 47+ min uptime w/ Telegram enabled = offset fix holding.

### Step 2 — persona pin remap (6 edits, 3 personas)
persona_02 p08 `pin 12→5`; persona_05 p07 `GPIO 12→16`; persona_06 p05 `25→22`, p06 `13→14,25→22` (18 kept), p08 `26→23,27→21`, p09 notes `25,26,27→22,23,21`. No intent changes. Verified 0 reserved-pin matches (correct regex `1[23]|2[4-9]|30`; directive's `[12][2-9]` regex is buggy — flags safe 14-19/22/23). scp'd to both Pis after Scott "go", on-Pi verified 7 files / 0 matches.

### Step 3 — firmware committed
`WireClaw-fork` wdl-v1 commit **bf80fa9** (author Scott Whitney, no Code byline), 3 files (tools.cpp/main.cpp/rules.cpp), pushed `4d07a81..bf80fa9` to origin/wdl-v1.

### Step 4 — overnight capture launched (19:11 MST)
pi02 PID 32702 (wdl_c6_02_bot, purge→.15), pi03 PID 7908 (wdl_c6_03_bot, purge→.47). Per-Pi config verified self-targeted. Full 7-persona rotation, no skip-list. **Auto-stop:** wrapper hardcodes 7AM (no SESSION_END_TIME env exists, contra directive); `at(1)` not installed → used detached `sleep→touch STOP_FLAG` watchdog @ 06:00 MST on each Pi (graceful; wrapper's 7AM check = backstop). Stale STOP_FLAG/status cleared pre-launch.

### Step 5 — liveness PASS (T+10)
Both Pis running, session #3 persona_03, 0 errors. Real model replies (not banners): c6-02 "…favorite color…is blue.", c6-03 "That's an error — the device registration call returned…". azza proxy accumulating from BOTH .15 & .47, newest 19:21 /v1/chat/completions.

### Open / queued
Phase 4.0.4 (boot-time rule revalidation vs pin allowlist — leftover-rules still boot-loop a flashed chip until cleared; broader snprintf audit; crash-detection watchdog). Phase 4.0.5 (c6-01 reflash, deferred). Monitor: persona_06 (remapped) will cycle in ~later sessions — first real test of safe-pin robotics prompts under capture; check morning corpus.

---

## (prior) Phase 4.0.4a IN PROGRESS notes — superseded by COMPLETE above

### Step 1 — verdict: no external sender; Telegram queue-replay was the cause

- **(a)** No sender procs on pi02 or pi03 (no `overnight_capture.sh`, `persona_runner.py`, telethon/driver). azza: no telethon session.
- **(b)** Dormant stale files only: `~/.telethon-pi02.session` (pi02), `~/.telethon-pi03.session` (pi03), both 05-18 06:53-06:54 (last night's killed run). Inert — no process using them. Recommend deleting before launch as hygiene.
- **(c)** azza proxy `ollama-raw/2026-05-19` dir empty/no records yet; no non-chip client IPs surfaced (inconclusive historically, moot given (a)).
- **(d)** No `/api/telegram` endpoint on either chip. Notable: **c6-02 uptime 47m 48s continuous, telegram enabled** — no poison-redelivery loop (fix holding). c6-03 stable.

**Conclusion:** The 4.0.3 persona prompts were Telegram server-side **queue-replay of last night's unacked backlog**, exactly what the tg-offset crash-safety fix + queue nuke resolve. No rogue sender. Stale `.telethon` session files are dormant artifacts (recommend deletion pre-launch).

### Remaining 4.0.4a steps (gated on Scott review of Step 1)

2. Persona pin remap (reserved→safe 0-11/14-23) + scp to both Pis. 3. Commit 3 fixes to wdl-v1 as Scott. 4. Launch 11h overnight capture (verify auto-stop fires — 4.0.1 flagged it didn't). 5. T+10min liveness check.

---



## Status: ✅ Root cause was NOT (only) the rulesSave OOB. The fleet-killer is **unvalidated `gpio_write` to ESP32-C6 reserved pins (flash GPIO24-30 / USB GPIO12-13)**, made permanent by **Telegram redelivering the unacked crash message**. Three firmware fixes applied, rebuilt, flashed to c6-02, and **validated live: 6+ min continuous uptime, zero resets, pin guard rejecting reserved pins gracefully under live persona load.** c6-03 NOT yet flashed. Commit + capture-relaunch NOT done — awaiting Scott direction.

---

## Why the original (4.0.1/4.0.2) diagnosis was incomplete

4.0.1/4.0.2 concluded `rst:0xc (SW_CPU)` from a `rulesSave()` snprintf OOB on rule creation crossing 4 KB. That bug is **real and fixed** — but it was not the primary fleet-killer. Reproduction on the reflashed c6-02 showed a *different* signature: `rst:0x8 (TG1_WDT_HPSYS)` watchdog reset triggered the instant the agent ran `gpio_write({"pin":26})` from the robotics_motion persona ("activate the spindle on GPIO 26", "motor outputs GPIO 18 and GPIO 25", etc.) — with **zero rules loaded**.

**True root cause:** ESP32-C6 **GPIO24-30 are the in-package SPI-flash bus** and **GPIO12/13 are USB D-/D+**. `tool_gpio_write` only checked `0 <= pin < SOC_GPIO_PIN_COUNT(31)`, so 24-30 passed. The personas explicitly instruct the model to drive GPIO 25/26/27 → the agent obeys → flash bus corrupted → hard fault → TG1 watchdog → reboot. Then **Telegram makes it unrecoverable**: `telegramTick()` set `tgLastUpdateId` in RAM only and acked the update on the *next* poll (offset+1). The chip crashes mid-`chatWithLLM()` before that next poll, so on reboot it re-fetches the SAME poison message → infinite crash loop. This is what bricked c6-pilot/02/03 overnight.

Secondary independent bug also observed & explained: a leftover `/rules.json` whose rule fires on boot hung `loop()` → same TG1 watchdog → boot loop, recoverable only by catching the ~1-2 s HTTP window to clear rules. (Mitigated in practice by the pin guard since the offending rule actions were reserved-pin writes; deeper rule-eval hardening queued 4.0.4.)

## Fixes applied (WireClaw-fork, branch wdl-v1, working tree — NOT committed)

1. **`src/tools.cpp` — central pin guard.** New `gpioPinReserved()` (C6: pins 24-30 flash, 12-13 USB, `#if CONFIG_IDF_TARGET_ESP32C6`) + `pinRejected()` graceful-error helper. Applied at every LLM pin-entry point: `tool_gpio_write`, `tool_gpio_read`, `tool_device_register`, `tool_rule_create` (sensor_pin/on_pin/off_pin), `tool_chain_create` (step pins). Reserved pins now return `"Error: ... GPIO N is reserved (SPI flash / USB) ..."` instead of crashing.
2. **`src/main.cpp` — crash-safe Telegram offset.** `tgSaveOffset()`/`tgLoadOffset()` persist `tgLastUpdateId` to LittleFS `/tg_offset`; saved **before** `chatWithLLM()` processes a message, loaded at boot. A message that crashes the chip can no longer be redelivered forever.
3. **`src/rules.cpp` — rulesSave() OOB fix** (from 4.0.2, retained): overflow-safe `rulesAppend()` + buffers 4096→8192. Still correct and necessary.

Build: `pio run -e esp32-c6` SUCCESS (Flash 52.0%, +~1 KB). `firmware.bin` sha256 `aa531aa237d56ac63a0a3c440297248a22bedc1bcb80492bf9192c819bfb5514`.

## Validation on c6-02 (live, on the rack, under real Telegram persona load)

Flashed via pi02 over the native USB-JTAG (component flash, `--no-stub --flash-size detect`, no `--baud`, by-id-resolved port — all 4 regions hash-verified). After power-cycle:

- **Uptime 6m 7s+ and climbing** (old firmware reset every ~11 s).
- **`rst:0x8 | rst:0xc | ESP-ROM` count = 0** in the full UART log — zero resets/crashes/reboots.
- **Pin guard proven live:** agent attempted `gpio_write`/`gpio_read` on reserved **GPIO 12** → `"Error: ... GPIO 12 is reserved (SPI flash / USB) ..."`, chip kept running. Identical code path protects flash pins 24-30 (the literal pin-26 killer).
- Rules created by the persona flow (`heater_reminder`, `temp_alert`, `temp_log`) all on safe pin 0, chip stable with them evaluating.
- `/api/status` 200, WiFi 192.168.1.15, heap healthy.

## Hard-won operational learnings (folded into skill + scripts)

- **CH343/UART0 is the reliable serial console** (stable across chip resets); the native USB-JTAG re-enumerates on every reset and a static reader on it produced a *phantom* `rst:0x8 loop` that cost hours. Always resolve devices by the **stable `by-id` symlink**, never `ttyACMn` (numbers flip on every re-enumeration).
- **esptool over C6 USB-Serial/JTAG:** no `--baud` (breaks stub), use `--no-stub`, `--flash-size detect` (chip is 16 MB; wrong size header → `rst:0x8` boot loop), RTS reset is a no-op (needs power-cycle).
- **Dual-USB during flash:** flash with ONLY the native USB-JTAG connected; CH343 DTR/RTS fights reset/strap. Reconnect CH343 only for read-only console.
- All captured in `/.claude/skills/esp32-c6-usb-ports/SKILL.md` and the `phase_4_0_3_*.sh` helpers.

## c6-03 — DONE (2026-05-18 ~19:40 MST)

Flashed via pi03 (component, `--no-stub --flash-size detect`, by-id `98:A3:16:97:DB:4C`), all 4 regions hash-verified, sha `aa531aa2…` (identical to c6-02). Post-power-cycle it hit the **leftover-`/rules.json` boot loop** (7x `rst:0x8`, boots→Ready→reset) — its old-firmware rules.json contained a poison rule. Cleared via the `/api/rules/delete {"id":"all"}` HTTP-window hammer (HIT #6). Now **stable: uptime climbing, 0 resets, 0 ESP-ROM, reachable .47, v0.4.0**. Both chips fixed.

### IMPORTANT hardening gap (Phase 4.0.4 — likely must-fix before fleet)

The pin guard validates at rule **creation** (tool call) only. Rules already persisted in `/rules.json` by the OLD firmware are loaded by `rulesLoad()` and fired by `rulesEvaluate()` **without re-validation** — so any fleet chip with a poisoned rules.json **still boot-loops even after flashing the fix**, recoverable only by the fragile ~1-2 s HTTP-window rule-clear. Fix options: (a) re-run `pinRejected`-equivalent on each rule in `rulesLoad()` and drop/disable offending rules, and/or (b) wipe `/rules.json` as part of the flash/recovery procedure. Until then, **every reflashed fleet chip needs its rules cleared** as part of recovery.

## NOT done / open
- **Not committed** — left as working-tree changes in WireClaw-fork for review. Commit message ready (see Phase 4.0.3 directive Step 10) but expand to cover all 3 fixes, not just rulesSave.
- **Capture relaunch (directive Step 8-10) NOT done** — and should be reconsidered: the **personas themselves instruct chips to drive reserved GPIO pins**. The pin guard now makes that non-fatal (graceful error), but the corpus will be full of "GPIO reserved" errors unless the personas are revised to use safe pins (0-11, 14-23). Recommend persona review before relaunch.
- **Open question:** Telegram persona prompts kept arriving with NO persona_runner on pi02/pi03 and the queue nuked — source unidentified (possibly another host's runner, or backlog). It served as useful live validation; the chip is robust to it now, but worth identifying before a controlled capture run.
- Phase 4.0.4 queue: rule-eval/chain hang hardening; non-ADC `analogRead` / `Invalid IO 255` HAL-noise hardening; the ~1-2 s-window rule-clear recovery is fragile.

## Standing / artifacts

WireClaw-fork @ wdl-v1 (uncommitted): `src/tools.cpp` (pin guard), `src/main.cpp` (tg offset persist), `src/rules.cpp` (rulesSave fix). Built `firmware.bin` sha256 `aa531aa2…`. Staged on pi02 `~/fw-4.0.3/`. c6-02 = .15 (FIXED, stable, on rack). c6-03 = .47 (untouched). Helpers `sdcard-images/phase_4_0_3_*.sh`. Skill `esp32-c6-usb-ports`.

Tag: "Phase 4.0.3 PIVOT — real fleet-killer = unvalidated gpio_write to C6 reserved pins (flash 24-30 / USB 12-13) + Telegram poison-redelivery. 3 fixes (pin guard, tg-offset persist, rulesSave OOB) applied + validated live on c6-02 (6min+ uptime, 0 resets, guard rejecting reserved pins gracefully). c6-03 + commit + capture-relaunch pending Scott; personas need revising to stop driving reserved pins."
