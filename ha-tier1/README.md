# ha-tier1 — Home Assistant Tier 1

**Scaffold only — no implementation as of the 2026-05-28 curtain call.**

This directory is a labeled empty room, not a build. It marks the repo on-ramp for the next chapter
of Project Opengates: a zero-firmware Home Assistant integration where HA supplies external ground
truth, so the 8B action-claim fabrication ceiling (the v1.3.x negative result) stops mattering.

## Read first

- **`../HA_TIER1_GROUNDWORK.md`** — the full design: rationale, scope, the verify-after-act
  approach, open questions, and the rough phase plan. **Start here.**
- `../PROJECT_EVALUATION_2026-05-28.md` — why HA Tier 1 is the chosen next chapter (path A → D).
- `../RESEARCH_FINDINGS.md` — the action-claim grounding negative result HA designs around.
- `../KNOWN_ISSUES_AT_REST.md` — open debts inherited into this chapter.

## Planned entry points (from the design doc — not yet created)

| File | Purpose |
|---|---|
| `ha-tier1/README.md` | This pointer + scope (created at curtain call). |
| `ha-tier1/ha_client.py` | Thin HA REST client (states + services); token from `Secrets.txt`. |
| `ha-tier1/ha_tools.py` | Agent-facing tool defs wrapping the client; allowlist + verify-after-act. |
| `ha-tier1/demo.py` | Natural-language → HA → grounded-reply demo. |
| `ha-tier1/eval/` | Small grounded-reply eval using HA true-state as the judge. |

## Status

Nothing here is implemented. No HA dependencies are added, no firmware is touched, no chip config is
changed. The v1.3.x research line stays rested; `wireclaw-agent:v1.3.1` is unchanged. Building begins
only on a future directive that opens the HA chapter (see the phase plan in
`../HA_TIER1_GROUNDWORK.md` §5).
