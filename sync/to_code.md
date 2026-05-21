# Instructions for Claude Code

## STATUS: ACTIVE — Phase 4.3.0 (two-pass inference firmware prototype)

[2026-05-20 18:07 MST: Phase 4.2.1.H complete — 3-chip overnight capture launched (evobot + pi02 + pi03 → c6-01 + c6-02 + c6-03 via wdl_c6_pilot/02/03_bot, full 7-persona rotation, 06:00 MST STOP_FLAG watchdog), T+10 liveness PASS, errors=0 across the fleet. Scott cleared and powered down.]

[2026-05-21 morning: Phase 4.2.1.I complete — 4,500-turn corpus aggregated (3 chips × 12 h, 0 boot-banner / 0 history-clear / 0 reset; cleanest capture in project history). Haiku-labeled at ~$5. v1.3.1 wrap-up regressed vs v1.1: fabrication 39.8% → 55.4%, with 44% of fabrications being action-claims with no tool_call fired. `deception_04` roleplay-jailbreak failed at both temps in production (lab was lucky variance). Zero model drift HF↔chip. Commit 2042b40, signed Scott Whitney. **Strategic decision: defer v1.3.2 training; pivot to firmware-side two-pass inference (Phase 4.3.0 below) to structurally eliminate action-claim fabrication before further LoRA spend.**]

---

## PHASE 4.3.0 — Two-pass inference pipeline (firmware prototype)

### Architectural reframe (per 4.3.0.A finding — 2026-05-21)

Code's 4.3.0.A walkthrough surfaced that the firmware **already runs a multi-iteration tool loop** (`MAX_AGENT_ITERATIONS=5`). When tools fire, iteration 0 already emits tool_calls and iteration 1 already emits wrap-up — that's structurally a two-pass setup. The fabrication site is NOT a missing pass; it's the **content-handling policy between iterations**. Specifically: iter-0's speculative `result.content` is being preserved into iter-1's context, and there's no explicit "you're in wrap-up mode now" directive constraining iter-1's output.

The 4.3.0 change is therefore a **wrap-policy fix on an existing agent loop**, not a new inference pass:

1. Discard `result.content` from any iteration that emits `tool_calls` (~1-line policy change at the content-preservation site).
2. Inject a `system`-role wrap-up directive into messages after tool_results are appended (~10-15 lines).
3. Gate both behind a runtime config flag (~15-20 lines for the `/api/config` field + reboot-to-apply).

Net implementation: ~30-35 lines of C. Same API-call count per turn. Latency unchanged. Diff under 100 lines.

**External framing still "two-pass inference for embedded agents"** for the eventual writeup — the model now sees a clean `tool_call → tool_result → wrap-up` sequence with no speculative middle, which is what "two-pass" means functionally. The reframe matters for the *internal* implementation story and the *publishable* finding (see 4.3.0.G).

### Goal in one line

Validate that the wrap-policy fix above structurally eliminates action-claim fabrication — the dominant failure mode in v1.3.1 production data (44% of all fabrications, 24.4% of all v1.3.1 turns), and specifically the **Site-2 subclass** (model fires tool but then claims action without grounding in result). Site 1 (model never fires tool) is deferred to 4.3.1 — requires a schema change (`tool_choice="required"` + no-op `respond_directly` tool) that deserves its own scoping pass.

### Why this, why now (read this once, then proceed)

- v1.3.1 overnight labels (4,500 turns across 3 chips, 12 h) show **55.4% fabrication rate, up from v1.1's 39.8%**. The regression's biggest subclass is **action-claim shape**: model says `"the rule has been deleted"` / `"the LED is now red"` without firing the corresponding tool. In the current single-pass inference flow, the model generates the wrap-up text in the *same* model call as the tool_call — i.e., it speculates the action completed before knowing whether the tool actually fired. With small-model capacity, that speculation goes wrong ~25% of the time.
- The two-pass pattern is the standard fix in cloud agent frameworks (OpenAI / Anthropic tool-use loops). It's underused on embedded agents only because of assumed latency/cost concerns on the second round-trip. We have evidence those concerns are weaker than assumed: Telegram interactions already tolerate seconds, and azza is on LAN/Tailscale with low per-call latency.
- If this works on a $5 chip with ~200 LOC of firmware, it's publishable. **Capture metrics with a writeup in mind:** clean before/after numbers, latency delta, token cost delta, behavioral examples.

### Authorization tiering for this phase

- Reading code, documenting flow, designing diff, drafting tests — **L0–L1**, autonomous within scope.
- Implementing the diff on a branch, building firmware, drafting flash plan — **L2**, autonomous within scope, report each step.
- **Flashing c6-01 — L3**, requires Scott confirmation per the firmware-flash precedent (Phase 4.0.x). Stop and wait at gate 4.3.0.E.
- **Flashing c6-02 or c6-03 — out of scope for 4.3.0.** Single-chip prototype only. Fleet rollout is a separate phase (4.3.1) gated on prototype results.

Use the standard refusal pattern (cite SOUL.md Article 15 + CLAUDE.md tier rules) if anything in the directive feels like it crosses these tiers.

### 4.3.0.A — Document the current inference flow (no changes)

Read the firmware tool-call handling path end-to-end. Best entry points likely live in `bench/fork/wireclaw-fork/src/` or wherever the LLM-client / chat / tool-call modules sit — grep for `tool_call`, `ollama`, `chat`, `api/chat`, etc. Identify and document:

1. The exact request shape the chip sends to azza (`/api/chat` POST body — system prompt + conversation history + user message + tool definitions).
2. The exact response shape azza returns (assistant message — does it contain tool_calls AND content together? Just tool_calls? Just content? What's the schema?).
3. What the firmware does between receiving the model response and sending the Telegram reply (parsing, tool dispatch, error handling, wrap-up generation, message-edit calls).
4. Where in the flow the speculative wrap-up gets emitted — is it from the model's `content` field returned alongside tool_calls? From a follow-up call already in code? Something else?

Write this up as `bench/fork/wireclaw-fork/docs/INFERENCE_FLOW_CURRENT.md` — a short architectural note with the actual code paths cited by file:line. This is the baseline reference for the diff.

**Report at this step** with the doc inline in chat (or as a from_code.md handback summary) before proceeding to design. Do not start changing code yet.

### 4.3.0.B — Design the wrap-policy fix (proposal, no implementation yet)

**STATUS (2026-05-21):** 4.3.0.B design doc complete at `WireClaw-fork/docs/INFERENCE_FLOW_TWO_PASS.md`. Scott + Cowork reviewed and approved with the following clarifications/adjustments for 4.3.0.C:

- **Wrap-up directive wording approved as drafted.** Five load-bearing clauses (temporal anchor / grounding constraint / error honesty / action-claim discipline / format guard). Optional micro-tweak: "natural English" → "natural language" for forward-compatibility, no required change.
- **System-role injection caveat for 4.3.0.F testing:** the injected wrap-up directive lands as a second `system`-role message mid-conversation. Llama-class models sometimes handle multiple system messages cleanly, sometimes drift. **If A/B in 4.3.0.F shows the directive isn't being honored** (e.g., wrap-ups still speculate, model ignores grounding constraint), test these alternatives before abandoning the approach: (a) inject as `user`-role with marker prefix, (b) fold wrap-up policy into original system prompt with conditional language, (c) use Ollama's template field. Don't pre-implement; be ready to swap if F surprises us.
- **Site-1 deferral approved.** 4.3.1 follow-up if Site 1 still dominant in residual fabrications after 4.3.0 lands. Doing both at once compounds risk and obscures attribution.
- **Config field name — Code's judgment call.** After the reframe, `inference_mode: "single" | "two_pass"` is technically misleading (firmware already does two-pass in both modes). Cowork recommendation: `wrap_mode: "speculative" | "grounded"` — describes the mechanism accurately. External writeup still says "two-pass inference for embedded agents" regardless of internal field name. **Code can keep `inference_mode` for continuity with directive/worklog/commit messages OR rename to `wrap_mode` — either acceptable.** If keeping `inference_mode`, document the reframe in the design doc so future readers find it.
- **Default `"single"` (or `"speculative"`) approved** — freshly-flashed chips behave like production until explicitly flipped. Safety-first.
- **`/api/debug/last_turn` endpoint deferred.** azza proxy log is canonical; chip-side endpoint duplicates capability. Keep diff under 50 lines total. If F needs per-turn data, pull from proxy (Phase 4.1.1 pattern).

**Original directive text for 4.3.0.B (kept for archive — the design doc supersedes):**

Based on what 4.3.0.A reveals, design the two-pass pattern. Cover:

1. **The two API calls.** Pass 1: request that the model emit tool_calls only (or "no tool needed, here's a direct reply" signal). Pass 2: request that the model emit wrap-up text given the tool_results already in context as tool-role messages.
2. **Edge cases:**
   - Pass 1 returns no tool_calls (model decides no tool needed) → skip pass 2, use pass 1 `content` directly.
   - Pass 1 returns multiple tool_calls → execute all in order, append all results, single pass 2.
   - A tool_call errors → append error as tool_result, let pass 2 generate appropriate "I tried but…" wrap-up.
   - Pass 1 returns tool_calls AND content (current model behavior likely does this) → discard content on pass 1, force the wrap-up to come from pass 2.
   - Model hallucinates a tool that doesn't exist → catch in dispatch, treat as error per above.
3. **Runtime flag for A/B.** Implement behind a config field like `inference_mode: "single" | "two_pass"` settable via `/api/config` so we can flip the mode at runtime without reflashing. This is essential for the A/B comparison in 4.3.0.F.
4. **Latency / token budget.** Estimate the worst-case end-to-end latency increase (pass 2 adds one HTTP round-trip + one model inference). Verify it stays inside the chip's HTTP timeouts and Telegram's message-edit latency tolerance. If a pass takes ~2–5s, two-pass might be 4–10s end-to-end — characterize this; Telegram users tolerate it but it's worth measuring.
5. **Token-budget concern:** the pass-2 prompt is larger than pass-1 (it includes the tool_results). Make sure conversation truncation logic still leaves headroom.
6. **Prompt-engineering side:** the system prompt currently presumably tells the model to "use tools when appropriate and reply in the same response." For two-pass, the model needs to know "on pass 1 emit tool_calls only; on pass 2 reply naturally using the tool_results visible to you." Either pass two different system prompts, or one prompt that handles both via context-sniffing. Recommend an approach.

Write the design as `bench/fork/wireclaw-fork/docs/INFERENCE_FLOW_TWO_PASS.md`. Include a sequence diagram (text-art is fine). Show me the doc before writing any code.

**Report at this step.** Hard gate: do not start implementation until Scott has reviewed the design proposal.

### 4.3.0.C — Implement on a branch

After Scott approves the design:

- Branch name: `phase-4.3.0-two-pass-inference`.
- Keep single-pass code path intact; gate two-pass behind the runtime flag.
- Add a small amount of structured logging to make A/B measurement trivial (per-turn: mode, pass count, latencies per call, tool_calls emitted, tool_results, final wrap-up — log to chip serial or to a buffer the `/api/debug` endpoint can return).
- Update tool definitions / system prompts as the design requires.
- Build firmware. Sign the binary with the standard chain.

Capture commit hash of the build; capture firmware SHA. Use bf80fa9 (current production firmware) as the diff base.

**Report at this step** with the diff summary (`git diff --stat phase-4.3.0-two-pass-inference..main` plus narrative on the non-trivial changes) before the flash step.

### 4.3.0.D — Pre-flash safety check

- Confirm c6-01 is the prototype target (currently on bf80fa9 + v1.3.1, paired with evobot). c6-02 and c6-03 stay on bf80fa9 untouched.
- Confirm c6-01 rule store and memory state are saved/exportable in case rollback is needed.
- Confirm bf80fa9 binaries are still on evobot from Phase 4.0.5 — if so, rollback is `phase_4_0_5_flash01.sh` against bf80fa9. If not, scp them back first.

### 4.3.0.E — Flash c6-01 (L3 GATE)

**STOP HERE.** Surface the design doc, the diff summary, the firmware SHA, and the rollback plan in chat. Wait for Scott's explicit "go" before flashing c6-01. This is a per-action L3 authorization (Article 15 / CLAUDE.md L3) — not satisfied by the directive existing.

When approved: use the standard JTAG flash pattern from `sdcard-images/phase_4_0_5_flash01.sh`. Verify all four regions hash-match post-flash. Reboot c6-01, confirm uptime monotonic, confirm `/api/status` returns the new firmware build hash, confirm `inference_mode` field defaults to whatever the design specifies (probably `"single"` for safety — then we flip to `"two_pass"` for testing).

### 4.3.0.F — A/B validation

Curated prompt set: pull ~20–30 known-fabrication-prone prompts from `bench/fork/lora/corpus/v1.3.1-overnight-2026-05-20.jsonl`. Mix of action-claim shape (the primary target), state-claim shape (secondary — shouldn't be helped by this fix, useful as a negative control), and clean baseline (shouldn't regress). Show the prompt set to Scott before running.

For each prompt, run **5x under `inference_mode: "single"` then 5x under `inference_mode: "two_pass"`** on the same chip (c6-01). Same conversation seed, same persona context, same model temperature. Reset chip rule store and memory file between runs to keep state clean.

Capture per-run: latency (pass 1, pass 2, total), tokens (per-pass and total), tool_calls fired (count + names), tool_results (success/error), final wrap-up text, and whether the wrap-up claims an action that wasn't backed by a tool_call.

Report: action-claim fabrication rate single-pass vs two-pass, latency overhead, token cost overhead, and any new failure modes the two-pass introduces (e.g., model refuses to wrap up, wrap-up becomes generic, latency exceeds Telegram tolerance).

### 4.3.0.G — Handback + recommendation

Write to `sync/from_code.md`:

- Headline: action-claim fabrication rate Δ (speculative → grounded), broken down by Site-1 vs Site-2 to isolate which got addressed.
- Latency overhead: median + p95 end-to-end seconds (expected: unchanged per design; verify empirically).
- Token cost overhead: per-turn token Δ (expected: +50–150 tokens from injected directive), project to monthly cost at typical traffic.
- Side effects: any new failure modes or improvements (e.g., does the wrap-policy fix also help with state-claim? memory-chain completion? roleplay-jailbreak? regression on any axis?).
- Recommendation: one of —
  - **Proceed to Phase 4.3.1 (fleet rollout + Site-1 schema fix)** — flash c6-02 and c6-03, then design `respond_directly` no-op tool + `tool_choice="required"` if Site 1 remains dominant in residual fabrications.
  - **Iterate on prototype** — specific issues to fix before fleet rollout (system-role injection didn't land, latency, token budget, prompt engineering).
  - **Abandon approach** — wrap-policy fix didn't help materially or introduced worse problems; reframe v1.3.2 scope to include action-claim training after all.

**Writeup notes — capture the three sharpened strategic findings for the blog-post-grade artifact:**

a) **v1.3.1 LoRA vindication.** If the wrap-policy fix recovers fabrication to v1.1 baseline or better, the v1.3.1 training did its job — the regression was an artifact of the firmware's content-handling policy, not of the training data. Capture before/after fab numbers with explicit attribution to the firmware fix, not the model.

b) **Sharpened publishable claim.** Frame the finding as: *"The dominant fabrication failure mode in embedded LLM agents is a content-policy bug in the agent loop, not a model-capacity limit."* This is more actionable for other embedded-agent projects than "use two-pass inference" — it tells them exactly where to look in their own codebases. Higher-impact contribution.

c) **Hardware-vs-model decision input.** If the firmware fix brings fabrication to acceptable territory, the remaining gap to "good product" is the genuinely capacity-bound issues (deception_04 roleplay, multi-step memory chains, authorization shape). Those are the issues a bigger model on a bigger azza would actually help with. Capture which residual failure modes look capacity-bound (would benefit from bigger model) vs policy/prompt-bound (could be addressed by further firmware or LoRA work). This is the input for the next strategic decision after 4.3.0.

**STOP** at handback. Do not flash c6-02 / c6-03. Do not initiate v1.3.2. Do not start HA Tier 1. Wait for Scott + Cowork's strategic call.

---

## Constraints (apply to all 4.3.0 work)

- Sign all commits as Scott Whitney
- Branch is `phase-4.3.0-two-pass-inference`; do not push to main until results review
- Flash gate at 4.3.0.E is a hard L3 stop — directive existence does not authorize the flash
- Single-chip prototype only — c6-01 is the target; c6-02 and c6-03 stay on bf80fa9
- No model retraining in this phase; v1.3.2 is deferred until two-pass results review
- Hardware: WSL-side keys (`~/.ssh/evobot_ed25519`), fleet routing patterns from CLAUDE.md still apply

## Reporting cadence

- After 4.3.0.A: doc inline in chat or via `from_code.md`, then wait for Scott to ack before B.
- After 4.3.0.B: design doc inline in chat or via `from_code.md`, **hard gate** — wait for Scott approval.
- After 4.3.0.C: diff summary inline in chat or via `from_code.md`, then proceed to D (pre-flash check) autonomously, then stop at E.
- 4.3.0.E flash: per-action approval, narrate each substep (scp, esptool, verify, reboot, status).
- 4.3.0.F: live updates as A/B runs complete; full data table in handback.
- 4.3.0.G: full handback for Scott + Cowork review.

## Out of scope (do not initiate)

- Phase 4.3.1 fleet rollout (gated on 4.3.0.G results)
- v1.3.2 LoRA synthetic generation or training (gated on 4.3.0.G results — scope may change)
- Phase 4.2.2 HA Tier 1 integration (gated on overall fabrication/safety story improving first)
- Phase 4.0.4 firmware hardening (boot-time rule revalidation, broader snprintf audit) — separate work
- azza GPU upgrade evaluation (future hardware decision, not this phase)
- Blog post draft (queue background once results land)
