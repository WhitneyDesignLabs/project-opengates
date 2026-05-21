# Instructions for Claude Code

## STATUS: ACTIVE — Phase 4.2.1.I (fresh-session pickup, morning of 2026-05-21)

[2026-05-20 18:07 MST: Phase 4.2.1.H complete — 3-chip overnight capture launched (evobot+pi02+pi03 → c6-01+c6-02+c6-03 via wdl_c6_pilot/02/03_bot, full 7-persona rotation, 06:00 MST tomorrow STOP_FLAG watchdog), launch PIDs evobot:8674/8678, pi02:7456/7460, pi03:13880/13884, T+10 liveness PASS with errors=0 across all three. Scott cleared and powered down. See sync/from_code.md top entry.]

---

## PHASE 4.2.1.I — Tomorrow morning fresh-session pickup

**This phase is for the FRESH Cowork + Code session that boots up when Scott powers his workstation back on tomorrow morning.** Read CLAUDE.md first (the protocol artifact), then this directive.

### I.1 — Verify auto-stop fired and capture is complete

```bash
wsl -- bash -lc 'for spec in "evobot:192.168.1.51" "pi02:192.168.1.17" "pi03:192.168.1.44"; do
  name="${spec%%:*}"; ip="${spec##*:}"
  echo "=== $name $ip ==="
  ssh -i ~/.ssh/evobot_ed25519 scott@$ip "
    pgrep -af overnight_capture.sh | head -1; pgrep -af persona_runner.py | head -1
    echo ---
    cat ~/.overnight-capture.status.final 2>/dev/null || cat ~/.overnight-capture.status 2>/dev/null
    echo ---
    ls -la ~/STOP_FLAG 2>/dev/null
  "
done'
```

Expected: zero running procs, STOP_FLAG present, `.status.final` showing session count. If anything's still running, pkill cleanly with bracket pattern (`pkill -f '[o]vernight_capture\.sh'`).

### I.2 — Pull corpus from all 3 Pis + azza proxy

```bash
wsl -- bash -lc '
DEST=/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-21
mkdir -p "$DEST/evobot" "$DEST/pi02" "$DEST/pi03"
scp -i ~/.ssh/evobot_ed25519 scott@192.168.1.51:~/wireclaw-corpus/user-side/*.jsonl "$DEST/evobot/"
scp -i ~/.ssh/evobot_ed25519 scott@192.168.1.17:~/wireclaw-corpus/user-side/*.jsonl "$DEST/pi02/"
scp -i ~/.ssh/evobot_ed25519 scott@192.168.1.44:~/wireclaw-corpus/user-side/*.jsonl "$DEST/pi03/"
ls -la "$DEST"/*/
'
ssh azza@azza.tail63f48.ts.net "ls -la ~/wireclaw-corpus/ollama-raw/2026-05-20/ ~/wireclaw-corpus/ollama-raw/2026-05-21/ 2>/dev/null"
```

### I.3 — Aggregate via merge_corpus.py from azza proxy data

Use the salvage pattern from Phase 4.1.1 — re-pair from azza proxy log (the canonical source). Outputs:
- `bench/fork/lora/corpus/v1.3.1-overnight-2026-05-20.jsonl`
- Per-chip split also available

Time-window: launch ~17:56 MST 2026-05-20 → stop ~06:00 MST 2026-05-21. Expected ~9K total turns across 3 chips (3K each, ~270 sessions × 7 personas if rotation runs uninterrupted; T+10 was ~30 turns/chip pace which extrapolates to ~6K — the directive's 9K estimate may be high, calibrate from actual).

### I.4 — Initial quality assessment (before labeling spend)

Report:
- Total turns per chip (raw + dedup)
- Per-persona breakdown per chip
- Any anomalies (resets mid-run, reply gaps, etc.)
- Sample 5 random turns per chip (15 total) for sanity check

### I.5 — Haiku labeling

Estimated cost: ~$10–15 for ~9K turns (Haiku 4.5 pricing). Surface estimate before spending.

Use the same labeling tool from Phase 4.1.4a. Same taxonomy (clean / pseudo-prose / fabricated / contradictory / error-reply / JSON-leak) plus the v1.3.1-target flags:
- `led_indirect_reference_bug`
- `reasoning_trace_leak`
- `memory_chain_correct`
- **NEW for this run:** `fabricated_state_claim` — explicitly flag turns where the model claims a system state (WiFi SSID, memory contents, file content) without having called the tool to retrieve it. This is the headline issue from Scott's 2026-05-20 5:13–5:30 PM probe.

Output: `bench/fork/lora/corpus-labels/v1.3.1-overnight-2026-05-20.labeled.jsonl`

### I.6 — Three-way comparison report

`bench/fork/lora/corpus-labels/v1.3.1-vs-v1.1-vs-3.1.3-comparison.md`. Per-label rates across all three corpora, with focus on:
- Did v1.3.1 preserve the v1.1 wins (clean rate, memory-chain)?
- Did v1.3.1's constitutional improvements show up in production rate? (Look for refusals in natural traffic — though personas don't usually fire harm-class prompts, anything detected is signal.)
- **`fabricated_state_claim` rate** — this is the next training target candidate
- Per-chip variance (is one chip more degraded than the others? would suggest hardware/RF issues not model issues)

### I.7 — Constitutional eval re-run against production v1.3.1

The eval suite has been tested against models in Ollama (azza). Re-run it against the deployed-on-chip v1.3.1 to confirm no drift between the published HF model and the actual chip behavior:

```bash
python bench/fork/lora/eval/constitutional_eval/runner.py --model wireclaw-agent:v1.3.1 --output results/v1.3.1-production-default.jsonl
python bench/fork/lora/eval/constitutional_eval/runner.py --model wireclaw-agent:v1.3.1 --temperature 0 --output results/v1.3.1-production-temp0.jsonl
```

Should match the v1.3.1 results from Phase 4.2.1.G (within sampling noise). If significant drift, investigate.

### I.8 — Handback for Scott

Write consolidated handback to `sync/from_code.md`:
- Corpus stats (volume, per-chip, per-persona, dedup counts)
- Three-way label comparison topline
- Top failure modes by frequency in v1.3.1 production data
- `fabricated_state_claim` rate (the headline signal from yesterday's probe)
- Constitutional eval re-run result
- Recommendation for next phase: v1.3.2 targeting fabrication, OR HA Tier 1 demo, OR something else informed by the data

**STOP.** Do not initiate v1.3.2 synthetic generation. Do not start HA work. Wait for Scott + Cowork's strategic decision based on the data.

---

## Constraints

- Sign all commits as Scott Whitney
- Sonnet for synthetic gen (when relevant), Haiku for labeling/judging (cost discipline)
- Do not run any model training tonight or tomorrow morning without explicit directive update
- The morning fresh session reads CLAUDE.md first, then this file's 4.2.1.I section

## Reporting cadence

Tomorrow morning (4.2.1.I): live reports at each step as the fresh session works through aggregation → labeling → analysis. I.5 cost estimate is the spending gate.

## Out of scope

- HA Tier 1 integration (Phase 4.2.2 — gated on tomorrow's data review)
- v1.3.2 synthetic generation / training (gated on tomorrow's data review)
- c6-pilot (c6-01) was revived today — its uptime data tonight is informative
- Phase 4.0.4 firmware hardening
- Blog post drafting (background)
