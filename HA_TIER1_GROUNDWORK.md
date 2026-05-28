# Home Assistant Tier 1 — Groundwork

**Status:** Planning / groundwork only. No implementation as of the 2026-05-28 curtain call.
**Author:** Cowork · **Context:** the chosen next chapter after resting the v1.3.x research line (see `PROJECT_EVALUATION_2026-05-28.md`).
**Purpose:** capture the concept, the rationale, the approach, and a phase plan so a future session can start building without re-deriving the design.

---

## 1. Why Home Assistant, why now

The evaluation established the project's real ceiling honestly: at 8B/8GB, the WireClaw agent governs behavior well (constitution, identity, refusals, safety) but cannot be trusted to *truthfully report its own actions* — action-claim fabrication sits around the ~44%-clean mark and resisted every lever we had. That makes it **unsafe for anything with irreversible physical consequences** and unimpressive as a pure command executor.

Home Assistant is the domain where that limitation stops mattering:

- **Physical state is independently verifiable.** HA already knows the true state of every light, switch, and sensor. If the model says "the living-room light is on" and it isn't, HA's own state is the ground truth — the fabrication is caught and correctable, not dangerous.
- **The failure mode is tolerable.** Occasional pseudo-prose ("the tool call was successful") is a cosmetic annoyance in a smart-home chat surface, not a safety event.
- **It's a real, demonstrable product.** "A $5 chip with a constitution that talks to your smart home" is a concrete demo. It turns the research into something showable.
- **It needs zero firmware changes.** The integration is REST-polling against HA's API from the existing agent surface — no chip reflash, no new safety-critical code paths.

This is the "stepping stone" tier from Scott's three-tier product vision (destination = robot fleet; ceiling = 8B proof-of-concept; stepping stone = HA). It's the right interim because it ships value at exactly the capability level we actually have.

---

## 2. Scope of Tier 1 (deliberately minimal)

Tier 1 is the smallest thing that demonstrates the concept end-to-end:

**In scope:**
- Read HA entity states (lights, switches, sensors, climate) via the HA REST API.
- A small set of safe control actions (toggle a light, set a thermostat target) — only on entities explicitly allowlisted.
- Route these through the existing WireClaw agent so the constitution still governs (refusals, authorization citations, safety warnings apply).
- A demo script / surface showing a natural-language request → HA state read or action → grounded reply, with HA's true state available as the verification backstop.

**Explicitly out of scope for Tier 1:**
- Any irreversible or safety-critical HA action (locks, garage doors, anything that could trap/harm). Article 3/4/15 territory — gate hard or exclude entirely.
- Firmware changes of any kind.
- Two-way automation authoring (the agent creating HA automations) — that's a later tier.
- Solving action-claim fabrication. Tier 1 *designs around* it (HA verifies state); it does not try to fix it.

---

## 3. Approach (zero-firmware, REST-polling)

The integration lives on the orchestration side, not the chip. The agent's tool layer gains HA-backed tools that call the Home Assistant REST API:

- **State reads:** `GET /api/states/<entity_id>` → return current state to the agent as a tool result. Because the tool result carries the *real* state, a grounded wrap-up is achievable even with the model's fabrication tendency — the right answer is in front of it.
- **Control actions (allowlisted only):** `POST /api/services/<domain>/<service>` (e.g. `light.turn_on`) → then immediately re-read the entity state and feed the *verified* post-action state back as the tool result. This is the key design move: **verify-after-act**, so the agent reports HA's confirmed state rather than its own claim.
- **Constitutional gate:** control actions pass through the same authorization logic the chip already uses — L2/L3 actions still require the citation/authorization behavior the model learned.

The "verify-after-act" pattern is also the conceptual seed of evaluation **option B** (firmware-side grounding enforcement): if HA-Tier-1 proves that re-reading true state after an action produces reliably grounded replies, that's direct evidence the same enforcement belongs in the chip's agent loop for the embedded case.

### Likely entry points (for the scaffold)
- `ha-tier1/README.md` — pointer + scope (created at curtain call).
- `ha-tier1/ha_client.py` (future) — thin HA REST client (states + services), token from `Secrets.txt`.
- `ha-tier1/ha_tools.py` (future) — agent-facing tool definitions wrapping the client, with the allowlist + verify-after-act logic.
- `ha-tier1/demo.py` (future) — the natural-language → HA → grounded-reply demo.
- `ha-tier1/eval/` (future) — a small grounded-reply eval using HA true-state as the judge.

---

## 4. Open questions to resolve at kickoff

- **HA instance + auth:** which Home Assistant install (existing? new? Is one of the project Pis a candidate host?), and a long-lived access token (stored in `Secrets.txt` alongside the others). Connector option: there may be a Home Assistant MCP connector worth checking before hand-rolling the REST client.
- **Allowlist policy:** which entities are safe for Tier 1 control. Default to read-only + a couple of obviously-safe lights/switches.
- **Where the agent runs for the demo:** on a chip (true to the product story but subject to the 8B limit) vs. on azza/workstation against the same model (cleaner for a first demo). Recommend azza-hosted for Tier 1 proof, chip-hosted for the showcase build.
- **Demo surface:** Telegram (reuse the existing persona/bot plumbing) vs. a small standalone CLI/web surface.
- **Success criterion:** define the grounded-reply rate target *with HA verification in the loop* — the hypothesis is it should be dramatically higher than the bare-model ~44% because true state is fed back before the wrap-up.

---

## 5. Rough phase plan (for a future directive — not started)

1. **Tier 1.0 — connectivity:** stand up / identify the HA instance, get a token, prove a REST state-read from the orchestration side.
2. **Tier 1.1 — read-only agent tools:** wire HA state-reads as agent tools; demo "what's the state of X" with grounded replies.
3. **Tier 1.2 — verify-after-act control:** add allowlisted control + the verify-after-act pattern; demo "turn on X" with HA-confirmed wrap-up.
4. **Tier 1.3 — grounded-reply eval:** small eval using HA true-state as judge; measure the grounding lift vs bare model.
5. **Tier 1.4 — showcase:** the demonstrable "$5 chip + constitution + your smart home" build, and the writeup/demo material.

Each tier is small and independently demonstrable. Tier 1.2's verify-after-act result is the one to watch — it's both the product win and the bridge to evaluation-option-B.

---

## 6. Relationship to the rested research

HA Tier 1 does **not** reopen the v1.3.x line. It keeps `wireclaw-agent:v1.3.1` exactly as-is and builds *around* its known limit. If anything, Tier 1 is the practical answer to the negative result: stop trying to make an 8B model honest about its actions in the abstract, and instead put it in a domain where the environment supplies the ground truth. That's a cleaner product story than "we eventually got fabrication under 4%," and it's reachable now.
