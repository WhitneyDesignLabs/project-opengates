# Quarantined corpus — NOT trainable

## `v1.1-overnight-2026-05-18.SCRAMBLED.jsonl`

- **Contents:** 3,030 turns from the 2026-05-18 → 2026-05-19 overnight v1.1
  capture run (c6-02: 1,580 turns / 158 sessions; c6-03: 1,450 turns /
  145 sessions). Window 2026-05-18 19:11 → 2026-05-19 05:58 MST.
- **Why quarantined:** prompt↔reply pairs are **scrambled**. Objective
  content probes: temperature-prompt→temperature-reply 14.5%,
  LED 11.0%, IP 4.5% (should each be ~100%). Lag analysis: 13.9%
  aligned / 11.5% one-behind / 74.6% neither — *not* a fixed offset
  (so not repairable by a simple shift). 16.5% of all replies are the
  literal string "History cleared" bleeding across unrelated prompts.
- **Root cause:** harness pairing bug in the Pi-side capture path —
  `bench/fork/lora/persona_runner.py` uses an uncorrelated FIFO
  (`_on_reply` enqueues every bot message; `send_and_await` pops the
  first one as "the reply"), with no Telegram `reply_to` correlation and
  no quiescence/settle. The WireClaw chip emits multiple messages per
  prompt plus unsolicited self-firing-rule messages, so pop-first
  mispairs at scale. Amplified by `overnight_capture.sh` rule-purge
  pointing at the wrong IP (.19 pilot) so self-firing rules were never
  cleared. NOT a model defect; NOT an external/phantom prompter (all
  candidate hosts swept clean; chip-side from_id is exclusively the
  operator's account). See `sync/from_code.md` Phase 4.1.1 §1.2.
- **Status:** preserved for diagnostic / salvage purposes ONLY. Do NOT
  train on this file. Do NOT Haiku-label it.
- **Salvage path (Phase 4.1.1):** the canonical corpus is the azza
  Ollama proxy log (stream 3), which carries the true request/response
  pairing. `bench/fork/lora/merge_corpus.py` already pairs from proxy
  records deterministically. If the azza proxy log covers the run
  window, the run is re-pairable offline into a clean 3,030-turn
  corpus (Path A). Otherwise a re-capture with the fixed harness is
  required (Path B). Decision gated on Scott.
