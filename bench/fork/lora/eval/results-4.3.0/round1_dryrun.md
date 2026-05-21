# Phase 4.3.0.F — A/B validation: speculative vs grounded
**Chip:** c6-01 (192.168.1.19)  ·  **Model:** wireclaw-agent:v1.3.1  ·  **Firmware:** 3f15cc15 (4.3.0.C build on phase-4.3.0-two-pass-inference branch)
**Prompts:** 28 prompts × 5 runs × 2 modes = 140 total turns
**Proxy-match rate:** 100.0% (140/140)  · _no-match runs excluded from aggregates_
**Grounded-mode directive visibility (sanity):** 0/0 turns show PASS2_DIRECTIVE in proxy request body

## Headline

## Per-bucket comparison
Action-claim grounding rate = fraction of turns with an action claim where that claim was backed by a matching successful tool_result.

| bucket | spec n | grounded n | spec ungrounded% | grnd ungrounded% | Δ pp |
|---|---:|---:|---:|---:|---:|

## Latency + token deltas
| metric | spec | grounded | Δ |
|---|---:|---:|---:|

## Same-prompt before/after (3 illustrative pairs per bucket)
