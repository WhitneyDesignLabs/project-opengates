# WireClaw corpus — manifest

This directory holds short manifests + sample slices of the WireClaw training
corpora. The **full corpora are not committed to this repo** — they live as
HuggingFace datasets to keep git diffs clean and to use the right tooling for
large JSONL artifacts. See each manifest section for the HF dataset link.

---

## `v1.1-overnight-2026-05-18.REPAIRED.jsonl` — 2026-05-19

**3,548 turns.** Recovered offline from the azza Ollama-proxy log of the
2026-05-18 → 2026-05-19 production overnight capture. Window: 2026-05-18
19:11:00 → 2026-05-19 06:02:52 MST. Pi02 ↔ c6-02 (`192.168.1.15`) and
pi03 ↔ c6-03 (`192.168.1.47`), 7-persona rotation, ~11 hours wall-time.

**Why recovered, not directly captured:** the Telegram-side capture stream
had a harness pairing bug (uncorrelated FIFO under multi-message chip
output) that scrambled prompt↔reply pairs at ~14% on-topic. The
authoritative ground truth is the proxy log, which carries deterministic
request/response pairing per `chat/completions` call. The salvage driver
imports `merge_corpus.merge_records_into_turns` and walks each user-side
session, filters proxy records by (`client_ip` + ts window), and emits the
repaired JSONL. See `sync/from_code.md` (Phase 4.1.1 §1.3) for the full
write-up and the scrambled counterpart at
[`quarantine/v1.1-overnight-2026-05-18.SCRAMBLED.jsonl`](quarantine/).

| Metric | Value |
|---|---|
| Turns | 3,548 |
| Proxy records consumed | 8,542 / 8,544 (2 boundary stragglers dropped) |
| Sessions | 303 (158 c6-02 + 145 c6-03) |
| On-topic temp prompt → temp reply | **83.0%** (scrambled: 14.5%) |
| On-topic LED prompt → LED reply | **78.1%** (scrambled: 11.0%) |
| On-topic IP prompt → IP reply | **88.5%** (scrambled: 4.5%) |
| Turns with non-empty `wrap_up_text` | 92.5% (3,282 / 3,548) |
| Persona-id fuzzy-match (metadata only) | 521 / 3,548 — re-tunable; non-blocking |

**Schema** (one JSON object per line):

| field | type | description |
|---|---|---|
| `id` | string | `{persona_id}-{persona_prompt_id}-{ts}` or `unmatched-{ts}` |
| `session` | string | `{chip}-overnight-{seq:03d}` |
| `ts` | string | proxy record timestamp (`YYYYMMDDThhmmss_micros`, MST) |
| `client_ip` | string | `192.168.1.15` (c6-02) or `192.168.1.47` (c6-03) |
| `prompt` | string | user message that opened the turn |
| `expected_tool` | string \| null | persona-prompt's expected tool (when matched) |
| `messages_sent_to_llm_iter1` | list | full chat history sent to the model on call 1 |
| `tool_calls_fired` | list | tool calls emitted by the model across the agentic loop |
| `tool_results` | list | tool execution results returned to the model |
| `wrap_up_text` | string \| null | model's natural-language wrap-up |
| `proxy_calls` | int | number of `chat/completions` calls in this turn's agentic loop |
| `_chip`, `_session_seq`, `_persona_name`, `_ts_window` | — | salvage-driver metadata |

**Sample:** [`v1.1-overnight-2026-05-18.REPAIRED.sample.jsonl`](v1.1-overnight-2026-05-18.REPAIRED.sample.jsonl) — first 10 turns, ~12 KB. Sufficient to inspect the schema and the agentic-loop trace shape.

**Full corpus location:** *(HuggingFace dataset, link forthcoming.)*

---

## `v1.1-overnight-2026-05-18.SCRAMBLED.jsonl` — quarantined

3,030 turns, kept in [`quarantine/`](quarantine/) as bug documentation. **Not trainable as-is.** See [`quarantine/README.md`](quarantine/README.md).

---

## Earlier corpora

Older runs (3.1.1 → 3.1.3, May 2026) are not republished — they were superseded by the v1.1 production capture and any analytic value lives in the worklog summaries.
