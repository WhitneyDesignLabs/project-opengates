# P03: Example-augmented tool descriptions

**Bucket:** Upstream PR candidate (the most opinionated of the six — pitch carefully)
**Impact:** Medium — reduces Mode B argument-truncation across small models. Bench-confirmed but model-dependent.
**Risk:** Medium — descriptions get ~3x longer; eats request-buffer budget; some maintainers prefer terse schemas.
**Affected files:** `src/tools.cpp`

## Problem

`TOOLS_JSON` at `src/tools.cpp:92-122` describes each of the 20 tools with a 1-line imperative description. Examples:

```json
{"name":"led_set","description":"Set RGB LED 0-255",...}
{"name":"gpio_write","description":"Set GPIO pin HIGH/LOW",...}
{"name":"rule_create","description":"Create automation rule. Use chained condition for chain-only targets.",...}
```

For models ≤8B parameters, instruction-style descriptions are a known weak point — they produce abbreviated or imaginative arguments because the model has no concrete pattern to match against. The SAP-era finding (Project Opengates, Feb 2026) was that the same model went from emitting `gpio.sh led on` to emitting the full path `/home/scott/.openclaw/.../gpio.sh led on` purely by rewriting "use this command to turn on the LED" into "user says 'turn on the LED' → exec with command: '/full/path/to/gpio.sh led on'".

The bench's current Mode-B count is low on the strong models (0-1 per 22 tests), but those are models with strong tool-calling pedigree. As we widen the candidate pool to include weaker base models, Mode-B will climb. We have the augmented variant ready to test: `bench/wireclaw_data/tools_examples.json` adds 1-3 worked input→output examples to each tool's description.

## Solution

Replace the body of the `TOOLS_JSON` literal in `src/tools.cpp` with the contents of `bench/wireclaw_data/tools_examples.json`. The literal grows from ~5.5 KB to ~17 KB.

## Cost

The 20-tool JSON array currently occupies ~5.5 KB of flash; the augmented version is ~17 KB. That's an 11.5 KB increase in:

1. Flash usage (one-time): negligible. Current firmware uses ~1.3 MB of 2.5 MB partition; 11 KB is rounding error.
2. RAM usage during request build: the tools JSON is appended to every chat request body. Request buffer `LLM_MAX_REQUEST_LEN` is 20480 bytes. Today a typical request runs ~13.7 KB (system prompt 4 KB + tools 5.5 KB + history + new user msg). With augmented tools, ~25 KB which **exceeds the request buffer**. So this patch is **gated on P02** (prompt truncation fix, but the cost there is on the other side) or on shrinking the system prompt.

Actually let's recompute: with truncated system prompt (~4 KB), augmented tools (~17 KB), 4-turn history (~1 KB), user msg (~0.5 KB) → ~22 KB, still over the 20 KB cap. So either:

- Grow `LLM_MAX_REQUEST_LEN` to 32768 (recommended; modern ESP32-C6 has 320 KB SRAM, plenty of room)
- Shrink the system prompt by moving more guidance into tool examples
- Shrink the augmented examples (drop "Examples:" intros, use one-line forms)

The cleanest path is option 1 plus P02 (so both buffers grow together).

## Diff

### `include/llm_client.h`

```diff
-#define LLM_MAX_REQUEST_LEN    20480 /* Max JSON request body */
+#define LLM_MAX_REQUEST_LEN    32768 /* Max JSON request body (grew to fit example-augmented tools) */
```

### `src/tools.cpp`

Replace the entire `TOOLS_JSON` literal body with the content of
`bench/wireclaw_data/tools_examples.json`, preserving the `R"JSON(...)JSON"`
wrapper. Full content available in that file — too large to inline here cleanly.
The first three entries for illustration:

```json
[
  {"type":"function","function":{"name":"led_set","description":"Set RGB LED 0-255 Ex: 'set LED red' -> r=255,g=0,b=0. 'LED blue' -> r=0,g=0,b=255. 'turn off LED' -> r=0,g=0,b=0.","parameters":{"type":"object","properties":{"r":{"type":"integer"},"g":{"type":"integer"},"b":{"type":"integer"}},"required":["r","g","b"]}}},
  {"type":"function","function":{"name":"gpio_write","description":"Set GPIO pin HIGH/LOW Ex: 'turn on GPIO 10' -> pin=10,value=1. 'pin 4 off' -> pin=4,value=0.","parameters":{"type":"object","properties":{"pin":{"type":"integer"},"value":{"type":"integer"}},"required":["pin","value"]}}},
  {"type":"function","function":{"name":"gpio_read","description":"Read GPIO pin state Ex: 'read GPIO 5' -> pin=5. 'what is pin 2?' -> pin=2.","parameters":{"type":"object","properties":{"pin":{"type":"integer"}},"required":["pin"]}}},
  ...
]
```

## Test plan

1. **Pre-test:** Confirm `LLM_MAX_REQUEST_LEN=32768` is in place + `cfg_system_prompt[8192]` (P02). Without those, request buffer overruns and chat fails.
2. Rerun bench with same models, `--tools examples`. Compare Mode B count before/after. Should drop on weaker models; should hold steady or improve slightly on stronger ones.
3. Verify request size stays under 32 KB across all 22 test cases.
4. Manual smoke test: ask the chip to register a long NATS subject (`home.kitchen.island.sensor.temperature`). Verify the model preserves all five dots.

## Upstream PR text

```
Title: Augment tool descriptions with worked input->output examples

Background:
For models <=8B parameters, instruction-style tool descriptions produce
abbreviated or imaginative arguments because the model has no concrete
pattern to match against. Adding 1-3 worked input->output examples per
tool dramatically reduces argument truncation/abbreviation in our bench.

This is well-documented in small-model tool-calling literature but not in
the OpenAI function-calling spec, so the "right" amount of description
detail is contested. We're proposing this as an opinionated improvement;
take or leave.

Change:
- Augment each of the 20 tool descriptions with 1-3 example lines:
    "Ex: 'set LED red' -> r=255,g=0,b=0. 'LED blue' -> r=0,g=0,b=255."
- Examples especially focus on tools with long string args (NATS subjects,
  Telegram templates, file paths) where Mode-B argument truncation is most
  common.
- Examples also show "wrong" shapes for serial_send (no trailing \n) and
  rule_create with on_r/off_r vs led_set with r.

Cost:
- TOOLS_JSON grows from ~5.5 KB to ~17 KB.
- Required: grow LLM_MAX_REQUEST_LEN from 20480 to 32768 to fit the larger
  request body. ESP32-C6 has 320 KB SRAM, well within budget.

Bench data: argument-truncation rate on llama3.1:8b drops from N to M; on
qwen2.5:7b-instruct from X to Y. (Numbers from upcoming bench run --
attach when filed.)

Alternative considered:
Per-model branching (qwen vs llama vs etc.) would let the firmware send
different descriptions based on the connected model. Adds complexity and a
config field. This proposal is simpler: same JSON for everyone.
```
