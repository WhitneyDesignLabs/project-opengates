# WireClaw Tool-Calling Bench

A test harness that sends **WireClaw-shaped chat-completions requests** to an
OpenAI-compatible endpoint (Ollama, OpenRouter, llama.cpp server, etc.),
runs each model through a fixed test suite, and classifies failures by mode.

## Why this exists

WireClaw's firmware silently drops tool-call attempts that come back as prose
instead of as a `tool_calls` field (see `src/llm_client.cpp:325-331`). On a
headless wire protocol with no human in the loop, a model that "tool-calls in
prose 1 time out of 5" will appear to ignore 1 out of every 5 commands. We
need to know which models do not do that against this specific tool palette
and this specific system prompt **before** we put any of them upstream of an
ESP32-C6.

The bench reproduces WireClaw's exact request shape (no streaming,
`max_tokens=2048`, `temperature=0.7`, `tool_choice=auto`) and runs against
either the **truncated** system prompt the chip actually sees today (4095
chars, because the firmware buffer is too small for the shipped 7266-char
prompt) or the **full** system prompt the README implies.

## Files

```
bench/
├── README.md                  # this file
├── requirements.txt           # `pip install -r requirements.txt`
├── run.py                     # main runner: python run.py --endpoint <url> --models <list>
├── classify.py                # failure-mode detectors and argument checkers
├── report.py                  # markdown scorecard generator
├── test_cases.yaml            # 22 test cases covering all failure modes
├── wireclaw_data/
│   ├── system_prompt_full.txt           # 7266-char shipped prompt (what README implies)
│   ├── system_prompt_truncated.txt      # 4095-char actually-loaded (what the chip sees)
│   ├── tools_stock.json                 # 20 tools as shipped (instruction-style)
│   ├── tools_examples.json              # tools augmented with worked examples (fork patch #2)
│   └── build_examples_tools.py          # script that builds the augmented variant
└── results/                   # populated at runtime
    ├── run-<ts>.json          # full raw results
    └── run-<ts>.md            # human-readable scorecard
```

## Setup

```bash
cd bench
pip install -r requirements.txt
```

## Running

### Baseline calibration (run this first)

```bash
python run.py \
  --endpoint http://azza.tail63f48.ts.net:11434 \
  --models opengates-agent:v1 \
  --prompt truncated \
  --tools stock
```

If `opengates-agent:v1` doesn't score very high on this (the known-good
configuration), the harness itself is wrong about WireClaw's wire format and
needs fixing before benching other models.

### Multi-model bench

```bash
python run.py \
  --endpoint http://azza.tail63f48.ts.net:11434 \
  --models opengates-agent:v1 qwen3-nothinker:latest qwen3:8b specialagentpuddy:8b voytas26/openclaw-qwen3vl-8b-opt:latest \
  --prompt truncated \
  --tools stock
```

### Prompt-variant comparison

To measure how much harm the 4095-char truncation does:

```bash
# What the chip sees today:
python run.py --endpoint <url> --models <model> --prompt truncated --out truncated-prompt

# What it should see:
python run.py --endpoint <url> --models <model> --prompt full --out full-prompt
```

### Tools-variant comparison

To measure whether fork patch #2 (example-augmented tool descriptions) helps:

```bash
python run.py --endpoint <url> --models <model> --tools stock    --out stock-tools
python run.py --endpoint <url> --models <model> --tools examples --out examples-tools
```

### Streaming probe (control test)

Confirms that `stream=true` silently drops `tool_calls` on Ollama (the Mode E
failure documented in Scott's primer):

```bash
python run.py --endpoint <url> --models opengates-agent:v1 --probe-streaming
```

Expected result: stream=false returns a tool_calls list of length 1;
stream=true returns N stream chunks with 0 tool_call deltas.

## Failure modes (legend)

The classifier maps each failed test to one of these modes:

| Mode | Name | Description | Detection |
|---|---|---|---|
| A | Text leak | Tool intent emitted as prose / fenced JSON / inline `tool_name(...)` syntax, no `tool_calls` field | Regex on content body |
| B | Argument truncation | Right tool, structurally valid call, but a string arg is missing characters or substrings | `contains_all` checker failures, exact-equality failures on long strings |
| C | XML format | Model emits `<tool_call>...</tool_call>` XML instead of OpenAI `tool_calls` JSON | Regex on content body |
| D | Drown / refuse | No tool calls, no leak markers, just prose | Catch-all for "model just chatted" |
| WRONG_TOOL | Tool selection | Called a tool but not the expected one | Tool name comparison |
| WRONG_ARGS | Arg correctness | Right tool, wrong args (not classifiable as B) | Checker failures |
| FORBIDDEN_TOOL | Direct-vs-rule | Used `rule_create` when direct action was expected, or vice versa | `forbidden_tools` list in test case |
| API_ERROR | Transport | HTTP error, timeout, malformed response | Exception during request |

Modes **A** and **C** are the most dangerous for WireClaw: the firmware
silently drops both. **B** is the second-worst: the chip thinks it heard the
command, but the action it takes is subtly wrong (truncated NATS subject,
abbreviated path, missing message template variable).

## Test case authoring

Each entry in `test_cases.yaml` has:

```yaml
- id: T01_led_red
  prompt: "Set the LED to red."
  pre_messages:         # optional prior context (for memory recall tests)
    - role: system
      content: "..."
  expected_tools: [led_set]
  expected_args:
    led_set:
      r: {exact: 255}
      g: {exact: 0}
      b: {exact: 0}
  forbidden_tools: [rule_create]    # optional
  mode_focus: B                     # primary failure mode this probes
  description: "..."
```

Argument checkers supported by `classify.check_arg`:

- `{exact: <value>}` — equality with int/str coercion tolerance
- `{contains: "foo"}` — case-insensitive substring
- `{contains_all: ["foo", "bar"]}` — all substrings present
- `{contains_any: ["foo", "bar"]}` — at least one substring present
- `{regex: "..."}` — regex search
- `{one_of: [a, b, c]}` — value in list
- `{integer_range: [min, max]}` — inclusive int range
- `{present: true}` — value just needs to exist

## Output format

Every run produces:

- `results/run-<ts>.json` — complete machine-readable record including each
  request's raw response, allowing post-hoc reclassification or deeper
  analysis without re-running the bench.
- `results/run-<ts>.md` — human-readable scorecard with summary table,
  per-test pass matrix, and per-failure details.

## Known facts about WireClaw's request shape

Captured from `src/llm_client.cpp:238-321` for fidelity:

- `"model"` — from config
- `"messages"` — array of `{role, content}` (and tool messages on follow-up)
- `"tools"` — full TOOLS_JSON array (20 tools, instruction-style descriptions)
- `"tool_choice": "auto"`
- `"max_tokens": 2048` — **hardcoded**, config field exists but is unused
- `"temperature": 0.7` — **hardcoded**, config field exists but is unused
- No `stream` key (defaults to false on both OpenRouter and Ollama)
- No `num_ctx`, `num_predict`, `keep_alive`, `top_p`, `top_k`, `stop`
- Request size cap: 20480 bytes (LLM_MAX_REQUEST_LEN)
- Conversation history: 4-turn circular buffer (MAX_HISTORY=4)
- TLS verification: disabled (`setInsecure()`) — irrelevant for local Ollama

The harness uses the same shape exactly, so a model that passes here is a
model that will work upstream of an unmodified WireClaw firmware.

## Calibration sequence (recommended)

1. **Stock everything, baseline model.** `--prompt truncated --tools stock` against `opengates-agent:v1`. Expect this to score well; if not, debug the harness.
2. **Run the streaming probe.** Confirms Mode E is real and `stream:false` is essential. One-time sanity check.
3. **Stock everything, candidate models.** Same flags, but with the live model list. Establishes which model is best with no firmware changes.
4. **Vary one axis: tools.** Re-run the top 2 models with `--tools examples`. Quantifies the value of fork patch #2.
5. **Vary one axis: prompt.** Re-run the top 2 models with `--prompt full`. Quantifies the harm done by the 4095-char truncation bug.
6. **Pick a winner.** Document the model + variant combination that produced the best WireClaw-specific score in task #6.
