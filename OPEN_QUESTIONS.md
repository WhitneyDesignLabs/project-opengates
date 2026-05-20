# Open Questions — Deferred Decisions

Single canonical list of all open decisions across the project as of 2026-05-13 evening. Scott deferred answering these to give himself time to absorb implementations. Future sessions read this when an answer becomes needed; mark resolved questions DONE inline and add new ones at the bottom of the appropriate category.

Items grouped by category. Each includes context, the actual question, and (where applicable) Cowork's recommendation at the time of deferral so Scott has a starting point when he returns.

---

## Phase 2C ship architecture (may resolve via Code's recon handback in current round)

### Q1 — Package branch name

Code will propose; Scott picks. Recommended in directive: `wdl-v1`, `package-v1`, `production`, `whitney-design-labs-v1`. Picks one that ages well — it'll be linked in the README. **Status:** pending Code handback.

### Q2 — README placement

Replace upstream `README.md` (clean for the fork's identity) or add a separate `README-WhitneyDesignLabs.md` (preserves upstream README, additive). **Status:** pending Code handback.

### Q3 — Defaults-flip mechanism

How the package branch enables baked mode by default: separate commit on the integrated branch (recommended — clean revertable diff), compile-time `#define`, or pure config.json documentation (no firmware change). **Status:** pending Code handback.

### Q4 — Repo description on origin

OK to edit `WhitneyDesignLabs/WireClaw`'s GitHub description to reflect the fork's purpose? Or leave as-is until Scott reviews live? **Status:** pending Code handback.

### Q5 — License footer in `bake/README.md`

MIT-equivalent matching upstream, or just reference upstream's LICENSE file by path? **Status:** pending Code handback.

---

## Modelfile v1.1 / v2 evolution

### Q6 — Disposition of v1.1 nits

Two v1.1 candidates were flagged after Phase 2A and remain unaddressed:
- T2 refusal worked but didn't cite "Article 3" by number. Add explicit refusal example to SKILLS.
- T1 invented "Software for Understanding and Lifecycle" as SOUL.md expansion. Add "SOUL.md is a proper noun, do not expand" directive.

Options: (a) fold into v2 LoRA training as preferred-target examples, (b) ship as a v1.1 Modelfile patch release after public ship, (c) drop entirely since v2 supersedes v1 anyway.

**Cowork recommendation:** option (a). The LoRA training corpus can carry these specific examples as preferred targets; this is a more durable fix than another SYSTEM iteration. Costs nothing extra in Phase 3.

---

## Upstream / Mario engagement

### Q7 — Mario silence timeline on P05 (#12)

P05 issue filed 2026-05-12. Etiquette guidance is "polite ping after 2-3 weeks of silence." How long to wait before pinging?

**Cowork recommendation:** 3 weeks. If no Mario response by ~2026-06-02, post a single polite check-in comment on #12. Don't escalate further if that doesn't elicit response — at that point P05 has effectively given Mario opportunity-of-first-refusal and we can re-evaluate.

### Q8 — Upstream PR ordering after P05 resolves

Plan-of-record from `bench/fork/PATCHES.md`: P05 → P01 → P06+P08 paired → P02-redesign → P03-redesign (with wrap-up coherence caveat). P04 skipped/superseded. P11 inserts where in this sequence?

**Cowork recommendation:** P11 slots between P01 and P06+P08. Rationale: P11 is small, fork-friendly, and enables the baked-model use case which is increasingly the project's identity. Sequencing: P05 → P01 → P11 → P06+P08 → P02-redesign → P03-redesign.

---

## Deferred patches (drafted, never implemented or never evaluated)

### Q9 — P08 (config write-side completeness): implement when?

Write paths in `web_config.cpp`, `setup_portal.cpp`, and the `tool_file_write` guard all currently block setting new config fields. P06's `temperature`/`max_tokens` and P11's `use_modelfile_system` are inaccessible via config UI. Operator must edit firmware default + reflash.

**Cowork recommendation:** P08 implementation as Phase 2C+1 polish work (after ship, before Phase 3.1 corpus capture). Reason: Phase 3.1 will involve flipping config flags repeatedly across the chip fleet; write-side UI access becomes operationally useful at that scale. Estimate: 2-3 hours of Code work.

### Q10 — P09 (file_read/file_write buffer expansion): implement when?

Current 512-byte cap silently truncates large files (bit us during Phase 1 step-4 reconfig when stale config.json dump masked URL path). Drafted as patch doc, never built.

**Cowork recommendation:** defer until empirically reachable. Phase 3 may not need it (memory.txt is short, persona scripts can manage shorter file ops). Revisit if Phase 3 corpus capture hits the limit.

### Q11 — P10 (strict numeric arg parsing): implement when?

Step-5 probe-A bug: model emitted `"threshold":"30"` as string, chip parsed as 0. May have been incidentally relieved by P03's int-arg examples; would need empirical re-test to know.

**Cowork recommendation:** test first, implement only if still present. Phase 3.4 eval will surface this naturally — if v2 emits int args reliably, P10 may be unnecessary.

### Q12 — F01 (Ollama defensive opts: stream:false, num_ctx, keep_alive): evaluate when?

Fork-only patch, drafted but never benchmarked. Could be useful for the production package's stability.

**Cowork recommendation:** evaluate during Phase 3.1's chip-fleet flash. The fleet running for weeks gives natural exposure to whatever Ollama-side weirdness F01 protects against (timeouts, model unload, cold-start). Implement only if a real failure mode surfaces.

### Q13 — P12 (wrap-up assertion check): build before, during, or after LoRA work?

Firmware-side guardrail that compares wrap-up claims to actual tool calls fired and intervenes on mismatch. Catches fabrication at point-of-harm.

**Cowork recommendation:** after Phase 3.0 (the Claude-judge wrap-up classifier). Both efforts share the wrap-up-quality detection infrastructure — once 3.0 builds the classifier, P12 can reuse the rubric on-chip with much less work. Also: even after v2 LoRA reduces fabrication frequency, P12 catches the residual; it's a complement, not a substitute.

---

## Phase 3 specifics (PHASE3.md tracks these)

### Q14 — Pi cluster networking topology

WiFi (simple, lower throughput, all Pis already capable) vs Ethernet (faster, requires switch). Newly relevant given Scott's rig vision (PoE switch in inventory).

**Cowork recommendation:** PoE Ethernet for production capture, given the rig direction. Pi 3 doesn't have native PoE — needs PoE HATs (~$25/Pi) or PoE+USB power injection. **Updated 2026-05-15 evening for the 3+1 topology:** 4 PoE HATs total = ~$100 (3 driver Pis + 1 status-display Pi), down from the original 7-Pi estimate of $175. Worth it for cabling cleanliness + reliability under sustained overnight runs.

### Q15 — Cloud GPU provider choice

Brev mentioned. Alternatives: Lambda Labs, RunPod, vast.ai. Choose based on cost/latency tradeoff.

**Cowork recommendation:** RunPod for first burst — lowest friction setup, A100-80GB at ~$1.50/hour. Move to Lambda or vast.ai if RunPod throughput disappoints.

### Q16 — Publish training corpus (Phase 3 output)?

Public reproducibility benefit vs PII review burden on captured Telegram messages.

**Cowork recommendation:** publish a sanitized subset. Code's labeling phase (3.2) generates a curated corpus naturally; that's what publishes. Raw captured conversations stay private. Best of both: reproducibility for the training process, privacy for the raw operator data.

### Q17 — Phase 3 iteration depth: stop at v2 or continue iteratively?

Open-ended. Decide after v2 results.

**Cowork recommendation:** defer this decision. Plan for v2 fully; if v2 succeeds and there's clear residual failure modes, v3 becomes worth considering. If v2 is good enough, declare victory and move on.

---

## Real sensor integration

### Q18 — Resume DHT22/BME280 wiring on ESP32-C6 board 02?

Was the "next chip-side work" item, deferred through bake pivot. Scott's physical wiring progress unclear.

**Cowork recommendation:** resume during Phase 3.1's fleet flash setup. Real-sensor data adds value to the corpus (temperature variations actually triggering rules vs synthetic constants). Could be one persona's specialty in the synthetic-user fleet.

---

## Publishing / strategic

### Q19 — Public-facing blog or paper writeup?

Phase 3 plan flagged the multi-turn fabrication finding and the hardware-budget angle as worthwhile blog/paper material. No commitment.

**Cowork recommendation:** opportunistic post-ship draft after Phase 2C lands. The fabrication-discovery story is genuinely novel and worth ~1500 words. The hardware-budget angle has clearer audience appeal but is also more saturated content territory. Lead with the fabrication finding.

### Q20 — When to share with M64GitHub community vs. keep fork-private?

Phase 2C ship makes the fork repo a public artifact. Question is when to actively promote (Reddit, HN, ESP32 forums) vs let it sit and grow organically.

**Cowork recommendation:** let it sit through Phase 3. Promoting now invites traffic before v2 is ready; promoting at v2 ship gives a story arc (we shipped v1 as opt-in, then v2 with LoRA improving the specific weak axis). Better narrative.

---

## Chip operational hygiene

### Q21 — Clean up rule_02 / rule_03 on chip?

Worklog flagged these were firing every 5 minutes from earlier probe tests. Unclear if cleaned via web UI Delete All.

**Cowork recommendation:** Scott verifies via Telegram `/help` or web UI Rules tab; deletes if still present. Operational hygiene, blocks nothing, but worth checking before board 1 is reassigned to Phase 3.1 capture duty.

### Q22 — Remove stray `-H` file in fork root?

Untracked, May 11 typo artifact. Trivial.

**Cowork recommendation:** Code does this as a one-line during Phase 2C ship since it's touching the fork tree anyway. Add to step 3 or step 4 of the current directive.

---

## Documentation hygiene

### Q23 — Fold fork-structure reference appendix into `bench/fork/HANDOFF.md`?

I said I'd do this after Phase 1; never did. The "P06 globals in main.cpp not separate module" lesson + the COM17 vs COM16 lesson belong in HANDOFF.md so future Code sessions don't re-stumble.

**Cowork recommendation:** Cowork (me) does this directly, in parallel with whatever else is in flight. ~15 minutes of work. Should land before Phase 3 wakes new sessions.

---

## Add new questions below this line as they arise

### Q24 — Status-display rack unit (the 4th Pi): application choice

The 2026-05-15 evening pivot from 7 capture pairs to "3 capture pairs + 1
status-display Pi" leaves the display node's app TBD. Sketched options
in `bench/fork/lora/RIG.md` "Status-display node":

- Live capture-rate dashboard (Flask + Chart.js, full-screen Chromium).
- Raw serial-tail of one chip on the LCD.
- Aggregate stats poster (big-print numbers).
- Hybrid / alternating views.

**Cowork recommendation:** start with raw serial-tail — it's by far the
lowest implementation effort (one `ssh` + a `cat`-like loop) and produces
the most immediately visible "rack is alive" signal. The dashboard is a
better long-term build; queue it for Phase 3.1.5 once the captures are
reliable and Scott has a stable picture of what he wants to see at a glance.

### Q27 — Chip `/api/*` endpoints are fully open (security note, deferred)

**Surfaced by Code 2026-05-16 during the rule-purge endpoint hunt.** The
WireClaw firmware's HTTP API has **no authentication** on any `/api/*`
endpoint, including the rule-delete one we now use as a session bookend.
The web UI Rules tab's "Delete All" button works because any LAN-reachable
client can POST to `/api/rules/delete` unauthenticated; that same property
means anyone on the LAN can also:

- Delete all rules at any time (denial of service against an automation
  installation).
- POST `/api/config` to change the chip's behaviour — including pointing
  Ollama at a hostile server, changing Telegram credentials, swapping
  models, flipping the P11 `cfg_use_modelfile_system` flag.
- Reboot the chip via `/api/reboot`.

**Current threat model is "LAN-only exposure" — acceptable for a workshop
deployment** behind a trusted router, not acceptable for any internet-
exposed install or any deployment on a shared/guest network. The Phase 3.1
capture lab is firmly on the safe side of this; production deployments may
not be.

**Mitigations to consider when this comes off the deferred shelf:**

1. *Bearer token in `data/config.json`.* Simplest. Chip reads a secret on
   boot; rejects `/api/*` requests without `Authorization: Bearer <token>`.
   Operator includes the token in any external script (the overnight
   wrapper, the persona runner if it ever talks to `/api/*` directly).
   Mid-effort firmware patch.
2. *IP allowlist in `data/config.json`.* Chip checks the client IP
   against a CIDR list and rejects anything else. Less granular than
   bearer-token but doesn't require client-side cooperation.
3. *Disable the dangerous endpoints by default.* `/api/config` and
   `/api/reboot` should arguably require a flag in `data/config.json`
   to enable at all — opt-in admin surface, not opt-out.
4. *Combined approach: bearer token for write endpoints, no auth on
   read endpoints.* Most pragmatic. `/api/status`, `/api/rules` (list),
   `/api/devices` stay open for monitoring; `/api/rules/delete`,
   `/api/config`, `/api/reboot` require the bearer.

**Project recommendation when this surfaces as urgent:** option 4 as an
upstream PR to M64GitHub/WireClaw — it's a genuine security improvement
the upstream maintainer would likely accept, and it puts the work where
the broader community benefits. Pair with a `data/config.json` schema
addition for `admin_token` + `read_only_endpoints` list.

**Out of scope for 3.1.2 and Phase 3 generally.** Recorded so it doesn't
get forgotten the day someone wants to put a WireClaw chip on a shared
network.

### Q26 — Non-human prompt sources: MCP / MQTT bridge architecture (roadmap)

**Raised by Scott 2026-05-16.** Production deployments of these ESP32 agents will
likely have *non-human* prompt sources — upstream AI orchestrators, MQTT
brokers feeding sensor-triggered actions, MCP servers exposing the chip as a
callable tool to higher-level systems. The chip's prompt input may rarely be
a person typing on Telegram.

Three rough architectural shapes for the bridge:

1. **Chip subscribes to MQTT directly.** Native protocol on the chip; lowest
   latency. Requires WireClaw firmware change to add an MQTT client task and
   wire MQTT message handling into the same `data/system_prompt.txt` +
   `tools` pipeline that Telegram uses today.
2. **MQTT-to-Telegram bridge** (external process). Chip firmware unchanged.
   Bridge subscribes to MQTT, posts to a Telegram bot the chip already
   talks to. Operationally messier (extra hop, extra creds, extra latency)
   but zero firmware risk.
3. **MCP server exposes the chip as a callable tool.** An MCP server (likely
   on azza or a spare PC) presents each chip's capabilities as MCP tools to
   higher-level AIs (Claude, custom agents). The MCP server speaks to the
   chip via its existing `/api/*` endpoints — no firmware change. Cleanest
   integration with the Claude / AI ecosystem we already use; most aligned
   with the Project Opengates direction.

**Implications for v1 LoRA training corpus** (already folded in 2026-05-16
when personas 05-07 were written): persona prompts include a mix of human-
conversational, mid-technical automation-system voice, and terse M2M
command-style — so the v1 training distribution has some representation of
non-human input shapes even before any bridge is built.

**Implications for v2+ classifier rubric** (NOT yet implemented): the
current rubric is implicitly human-centric. `pseudo-prose` is a failure
class because humans find `(led_set(r=255,g=0,b=0))` jarring; for an MCP/MQTT
consumer that's arguably preferable (parseable, unambiguous). Consider
adding a "consumer-context" axis in v2 corpus design — clean natural English
for human consumers, clean structured response for M2M consumers. v1 still
optimises for natural English; the structured-response axis can wait until
M2M deployment actually happens.

**Decision points** (deferred):
- Which bridge shape to build first. Recommend MCP server (#3) — leverages
  the Claude ecosystem, minimal chip-side risk, clean separation of concerns.
- Whether the v2 corpus capture loop should add an MCP-driven persona —
  literally an MCP client driving prompts via the bridge, with the agent's
  reply going back through the bridge to a logging sink. End-to-end M2M
  capture.
- Whether the wrap-up classifier rubric grows a consumer-context dimension
  in 3.0-v2.

### Q25 — `OLLAMA_NUM_PARALLEL` experiment timing

The 3-chip ceiling derived from `OLLAMA_NUM_PARALLEL=1` (Ollama default).
If Ollama 0.x can run `=2` on 8 GB Pascal with the 8B bake's context size,
the ceiling doubles to ~6 useful chips and the 3-active topology becomes
self-imposed rather than hardware-forced. Worth a one-evening experiment.

**Cowork recommendation:** run the experiment AFTER the morning report from
the current overnight, before Phase 3.1.2 build-out. If `=2` works, the
3.1.2 plan stays the same (3 chips is still a clean V1) but we know the
ceiling is elastic. If `=2` OOMs or destabilises, the 3-chip ceiling is
load-bearing and Phase 3.1.2 is the final scale-out shape.
