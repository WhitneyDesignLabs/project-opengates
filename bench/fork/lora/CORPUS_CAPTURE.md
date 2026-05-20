# Corpus capture — three-stream architecture

How conversations are turned into Phase 3 training corpus. Pilot uses the minimum
viable subset; the at-scale architecture adds one stream and one merge step.

## The three streams

Each user turn through WireClaw produces evidence in three places:

1. **User-side** — the prompt the user (Scott, or a Telethon synthetic-user
   account) sent via Telegram, plus the chip's final Telegram reply (the
   *wrap-up text*).
2. **Chip-side history** — the chip's `/history.json` on LittleFS, a 4-turn
   circular buffer of `{role, content}` messages from the chip's own perspective.
   Holds the user prompt + the chip's wrap-up exactly as the chip saw them.
3. **Ollama-side ground truth** — the chip makes one or two `/v1/chat/completions`
   calls per user turn (call 1 returns structured `tool_calls` the chip executes;
   call 2 produces the wrap-up text from the prior context + tool results). The
   full REQ_BODY of both calls — system prompt, all messages, tools array, the
   model's full response including `tool_calls` arguments — is the canonical
   record of *what actually happened weight-side*.

The seed-corpus JSON shape (see
`seed-corpus/phase2b-chipside-2026-05-13.json`) is populated by joining these
three streams.

| Field | Source |
|---|---|
| `id` | assigned at capture time (`<persona>-<prompt_id>-<session_ts>`) |
| `prompt` | stream 1 |
| `messages_sent_to_llm_iter1` | stream 3 (REQ_BODY of call 1) |
| `tool_calls_fired` | stream 3 (response of call 1) |
| `tool_results` | chip-side execution output (serial, or chip API if exposed) |
| `wrap_up_text` | stream 1 (Telegram reply) — also in stream 2 |
| `human_label` | added post-capture by hand-labelling or the wrap-up classifier |

## Pilot capture (streams 1 + 2 only)

For the single-pair pilot we use a **two-stream** subset and accept a partial
corpus:

- **Stream 1** — Scott drives the prompts manually via Telegram; the Pi (or just
  the chat itself) records the prompts + wrap-up texts as a flat log.
- **Stream 2** — after the smoke battery, pull `/history.json` from the chip.
  **Finding from the 2026-05-15 pilot:** the current firmware has *no* generic
  web file/history endpoint — only purpose-built `/api/*` routes (e.g.
  `/api/temperature`, `/api/led`). `/history.json` is not pullable via web UI.
  For the pilot, the equivalent information came from the COM serial monitor
  (tool calls + execution traces, captured live during the battery) joined with
  Telegram (wrap-up text). At scale, the stream-3 proxy is the canonical source
  and stream 2 stops mattering.

What the pilot corpus *will not* have without stream 3: the `tool_calls_fired`
ground truth and the `messages_sent_to_llm_iter1` REQ_BODY. That's fine for the
pilot — the goal is verifying `wdl-v1` works end-to-end and validating the corpus
plumbing, not building a labelled training set. The captured `wrap_up_text` plus
the persona's `expected_tool` annotations are enough to let
`bench/wrap_up_classify.py --corpus <pilot>.json` run and produce labels for the
wrap-ups we did capture.

If during the pilot Code temporarily re-enables the chip's REQ_BODY printf (the
one that lived on `p11-test`), the serial log on COM17 gives a manual chip-side
ground-truth stream — usable for one pilot session but not how at-scale capture
should work.

## At-scale capture (Phase 3.1 — adds stream 3)

For 7-chip fleet capture we add stream 3 as the canonical source:

- **Ollama-side logging proxy on azza.** A thin wrapper (Python aiohttp or an
  nginx mirror) sits in front of `/v1/chat/completions`. For each request: log
  the request body, forward to real Ollama, log the response body, forward back
  to the chip. One JSON record per (chip-IP, timestamp) pair, written to
  `azza:~/wireclaw-corpus/ollama-raw/<date>/<chip-ip>_<ts>.json`. The proxy adds
  ~milliseconds of latency; chips don't notice.

- **Pi-side persona driver** — `bench/fork/lora/persona_runner.py` (written +
  dry-run-smoke-tested 2026-05-15; deployed to EvoBot in Phase 3.1.1). An async
  Telethon client that logs in as a Telegram **user** account (one account per
  persona; first run prompts for an SMS code, persistent session file after
  that), sends each persona prompt to the target chip-bot via
  `client.send_message`, awaits the reply via `events.NewMessage(from_users=bot)`,
  paces by the persona's `INTERACTION_DELAY_S`, and writes one JSONL line per
  prompt/reply pair to `~/wireclaw-corpus/user-side/<persona>_<session_ts>.jsonl`.
  `/clear` is sent to the chip-bot at session start and end so `/history.json`
  is bounded. Auth (`TG_API_ID`, `TG_API_HASH`, `TG_PHONE`) comes from env vars
  populated from `Secrets.txt`; never on the command line.

- **Merge step**, run on demand after a capture session:
  `bench/fork/lora/merge_corpus.py` (**written + smoke-tested 2026-05-15**) reads
  the proxy-raw JSON files from a directory (recursive), groups records into
  conversation turns via the "new-user-message" heuristic, extracts
  prompt + `tool_calls_fired` + `tool_results` + `wrap_up_text` per turn, fuzzy-
  matches each turn to the named persona's `PROMPTS`, and emits a seed-corpus-
  shape JSON to `bench/fork/lora/corpus-raw/<session>.json`. Usage:

  ```bash
  python3 bench/fork/lora/merge_corpus.py \
      --proxy-logs /tmp/proxy-pull/<date> \
      --persona persona_01_basic \
      --session-id <session> \
      --client-ip 192.168.1.19 \
      --out bench/fork/lora/corpus-raw/<session>.json
  ```

  Record-shape mapping (proxy → seed-corpus):
  - `record.request.messages` → conversation's `messages_sent_to_llm_iter1`
    (first call only — subsequent calls' messages are accumulated implicitly
    via the tool-results extraction).
  - `record.response.choices[0].message.tool_calls` → `tool_calls_fired`
    (flattened from OpenAI shape `{function: {name, arguments}}` to flat
    `{function, arguments}`; arguments JSON-parsed).
  - `record.request.messages[role="tool"].content` (newly-appearing in
    subsequent records) → `tool_results`.
  - `record.response.choices[0].message.content` (when no more tools fire)
    → `wrap_up_text`.

  The `proxy_calls` field on each turn records how many proxy entries
  contributed (1 for trivial-no-tool turns, 2 for typical tool turns, 3+ for
  sequential-tool turns).

  Then:
  - `bench/wrap_up_classify.py --corpus <session>.json --use-haiku` adds labels.
  - The labelled output feeds Phase 3.2 curation.

## Session boundaries

A "session" is one continuous run of one persona on one chip, with `/clear` at
both start and end so `/history.json` is empty going in and clean going out.
This bounds the 4-turn circular history and prevents cross-session contamination
of the corpus (the Phase 2B "self-reinforcing fabrication loop" was exactly the
failure of *not* clearing between runs).

For at-scale: the persona driver issues `/clear` to the chip-bot at session
start, runs N prompts, issues `/clear` again at session end. Each persona file
defines the prompt list and pacing; the driver runtime is shared.

## File layout

```
bench/fork/lora/
├── personas/
│   ├── persona_01_basic.py        # 10-prompt pilot persona (Scott-driven now, Telethon later)
│   └── ...                        # 02, 03, ... added in Phase 3.1
├── seed-corpus/
│   ├── phase2b-chipside-2026-05-13.json   # 4-conversation baseline
│   └── pilot-<date>/                       # populated this round
│       ├── history.json           # chip /history.json snapshot
│       └── corpus.json            # seed-corpus-shape, streams 1+2 merged
├── corpus-raw/                    # at-scale: one file per session, streams 1+2+3
├── corpus-curated/                # at-scale: post-classifier, post-hand-review
└── CORPUS_CAPTURE.md              # this file
```

`azza:~/wireclaw-corpus/` mirrors the structure for the on-server stream-3 logs
and for the user-side JSONL stream Pis write directly. Periodic rsync into the
fork tree promotes finished sessions into `corpus-raw/`.

## Stream-3 proxy — implementation status (validated 2026-05-15)

The Ollama-side logging proxy exists and is end-to-end validated on azza.

- **Script:** `bench/fork/lora/ollama_logging_proxy.py` (version-controlled in the
  workspace). Deployed copy: `azza:~/ollama_logging_proxy.py` (scp the workspace
  copy to redeploy — do **not** use `cat | ssh 'cat > file'`, the
  background-pipeline race truncates it; scp is atomic).
- **Stdlib only** — no venv/pip on azza (http.server + urllib). Listens
  `0.0.0.0:11435`, forwards to `127.0.0.1:11434`, logs one JSON record per
  request to `azza:~/wireclaw-corpus/ollama-raw/<YYYY-MM-DD>/<client-ip>_<ts>.json`.
- **Record shape:** `{ts, client_ip, path, upstream_latency_ms, status,
  request, response}` — `request`/`response` are the parsed JSON bodies. Maps to
  the seed-corpus `messages_sent_to_llm_iter1` (= `request.messages`) and
  `tool_calls_fired` (= `response.choices[].message.tool_calls`) per the stream
  table above.
- **Start (survives SSH exit — `setsid` required, plain `nohup &` gets reaped):**
  ```bash
  ssh azza@azza.tail63f48.ts.net \
    'setsid bash -c "python3 ~/ollama_logging_proxy.py >~/ollama_proxy.log 2>&1" </dev/null >/dev/null 2>&1 &'
  ```
- **Stop:** `ssh azza@azza.tail63f48.ts.net 'pkill -f "python3 .*ollama_logging_proxy"'`
- **Validation done:** one curl through `:11435` returned the upstream response
  unchanged (`PROXY_VALIDATION_OK`) and wrote a well-formed
  `~/wireclaw-corpus/ollama-raw/2026-05-15/127.0.0.1_*.json` (status 200,
  latency captured, request+response bodies parsed). Proxy then **stopped** —
  azza left clean, ollama `:11434` untouched. **Chips are NOT redirected**
  (still on `:11434`); the `cfg_api_base_url` → `:11435` cutover is a deliberate
  future Phase 3.1 step, not done here.
- **Known limitation (Phase 3.1 hardening):** buffers the upstream response as a
  single body. Correct for WireClaw (non-streaming, `Connection: close`). If a
  client sets `"stream": true` (SSE), the proxy would buffer and break
  incremental delivery — add chunked/SSE passthrough before any streaming use.
- **Firewall (azza `ufw`) requires an explicit allow rule for the proxy port.**
  Finding from Phase 3.1.0 (2026-05-15): azza's `ufw` was active with INPUT
  policy DROP, allowing only `22/11434/3000/4000`. The proxy port `11435` was
  silently blocked; the proxy itself started fine but the chip's LAN-side
  requests never reached it (loopback validation passed; LAN requests timed
  out). Symptom: chip returns `[error: LLM call failed]` over Telegram, proxy
  log has zero records from `192.168.1.x` clients. Fix:
  ```bash
  ssh azza 'sudo ufw allow 11435/tcp'
  ```
  Reversible: `sudo ufw delete allow 11435/tcp`. Phase 3.1.1's persistent-
  proxy setup **must** include this rule as part of deployment. Test it
  end-to-end with a chip-side curl, not just loopback.

## Privacy / PII

Telegram messages may contain whatever the operator typed (names, addresses,
schedules, etc.). Per `OPEN_QUESTIONS.md` Q16, the Phase 3.2 curation step is
where PII review happens; raw stream-1 captures stay private. The pilot's stream
1 is just the 10-prompt persona battery and Scott's hand-typed prompts, both of
which are project-shaped, not personal.
