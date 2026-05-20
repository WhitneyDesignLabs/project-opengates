# WireClaw Fork Patch Plan

Planning doc for the WhitneyDesignLabs fork of [M64GitHub/WireClaw](https://github.com/M64GitHub/WireClaw).

Each patch is described once here, then has its own file in `patches/` with the
actual diff and any rationale notes. Patches are ordered by impact-on-WireClaw-reliability
(highest first) and tagged for upstream PR vs fork-only.

## Bucketing

**Upstream PR candidates** — improvements that benefit any WireClaw user, regardless
of hardware or LLM choice. These should be submitted as PRs to `M64GitHub/WireClaw`,
preferably one issue + one PR per patch:

- **P01** Text-leak detector in response parser
- **P02** System prompt buffer truncation fix
- **P03** Example-augmented tool descriptions (TOOLS_JSON)
- **P04** T02 LED-vocabulary disambiguation in system prompt
- **P05** T19 serial_send description fix
- **P06** Wire up unused `max_tokens` / `temperature` config fields

**Fork-only** — specialized features tied to specific hardware or use cases that
upstream may or may not want. Stay in the WhitneyDesignLabs fork:

- **F01** Defensive Ollama options (`stream:false`, `num_ctx`, `keep_alive`)
- **F02** Optional XML `<tool_call>` parser branch (Hermes-style models)
- **F03** ESP32-C6 Zigbee end-device support (when scoped)
- **F04** MCP server endpoint exposing chip as MCP target (when scoped)
- **F05** SAP-style baked-personality system prompt (when scoped)

## Ordering rationale (priority-first)

| # | Patch | Impact | Risk | Why this order |
|---|---|---|---|---|
| P01 | Text-leak detector | **Critical** | Low | Stops the firmware from silently dropping commands when models prose-leak. Every reliability number this bench produces is meaningless until this is in. |
| P02 | Prompt truncation fix | **High** | Low | Restores the dropped half of `system_prompt.txt`, recovers T11 + T12 immediately. Quantified harm: 2/22 tests on the baseline model. |
| P03 | Example-augmented tools | **High** | Medium | Reduces Mode B argument-truncation. Bench-confirmed value depends on which model wins — re-test after applying. |
| P04 | LED vocab fix | **Medium** | Very low | One-paragraph rewrite of `system_prompt.txt` LED rules section. Recovers T02 on three of five models. |
| P05 | serial_send description | **Low** | Very low | One-line edit. Recovers T19 on opengates and qwen3. |
| P06 | Config wiring | Medium | Low | Without this, our Ollama-tuning options (lower temperature, model-specific max_tokens) are silently ignored. |
| F01 | Ollama defensive opts | High (locally) | Low | `keep_alive=24h` keeps the model loaded — 27s warm vs 60s+ cold per request. Big UX win on local LLM. |
| F02 | XML parser branch | Medium | High | Substantive code addition. Only worth doing if a Hermes-class model wins the bench. Defer until model selection settles. |
| F03 | Zigbee | Project-defining | Very high | Big undertaking, depends on hardware in hand and concrete use case. Defer until C6 is alive on the desk. |
| F04 | MCP server | Project-defining | High | Substantive architectural addition. Depends on whether we want chip-as-MCP-target or stay with NATS. Defer. |
| F05 | Baked personality | Quality-of-life | Low | Once we know the winning Modelfile recipe, bake it. Defer until model bench is finalized. |

## Apply order in the actual fork

When the GitHub fork exists at `WhitneyDesignLabs/WireClaw`, apply patches as
separate commits in this order (each commit ~ one patch):

```
git checkout -b sap-fork
# Apply P01 (most important, smallest dependency cone)
git commit -m "Detect prose-leaked tool calls in response parser

WireClaw's parseResponse() silently drops responses that contain
tool-call intent in prose form (XML tags, fenced JSON, inline call
syntax) but no structured tool_calls field. This means the chip
appears to ignore commands when the upstream LLM regresses to text
output.

Adds a leak-detection pass after tool_calls parsing; on detection,
logs to serial, does not save the leaked content to history (which
would otherwise reinforce the behavior on next turn), and returns an
explicit LLM_ERR_PROSE_LEAK status to the caller.

Refs: bench data showing 0/5 tested 8B models leak today, but Hermes/Qwen
XML-format models would 100% leak against the unmodified parser."

# Apply P02
git commit -m "Grow system_prompt buffer and surface truncation

cfg_system_prompt[4096] silently truncates the shipped 7266-byte
system_prompt.txt at byte 4095, dropping the entire 'Rule chaining',
'Managing rules', and 'Time-based rules' sections. Bench evidence:
T11 (periodic rule), T12 (time-based rule) fail on every tested model
because the relevant guidance is in the dropped section.

Grows the buffer to 8192 bytes (still well under PSRAM budget) and
adds a serial warning if the file exceeds the buffer."

# ...etc per patch...
```

## Upstream PR plan

Per the etiquette playbook: **open issues first, then PRs, one at a time**. Suggested
issue text templates and PR descriptions are in `upstream/`.

Order to file with M64GitHub:

1. **Issue: Tool-call prose leak silently drops commands** (P01)
   - Probably the easiest sell — pure bug, comes with reproducible bench data
2. **Issue: system_prompt.txt silently truncated to 4095 chars** (P02)
   - Pure bug, one-line buffer growth fix
3. **Issue: serial_send tool description ambiguous about newline** (P05)
   - Trivial doc fix, ideal first-PR contribution
4. **Issue: LED rule vocabulary collision in system prompt** (P04)
   - Slightly opinionated; describe with bench data
5. **Issue: Tool descriptions instruction-only — propose adding examples** (P03)
   - Most opinionated; pitch as optional, with bench data showing improvement on small models
6. **Issue: Hardcoded max_tokens/temperature ignore config** (P06)
   - Pure bug + obvious fix

Don't open all six at once — that looks like dumping a backlog on a solo maintainer.
Lead with P05 (smallest, friendliest first contact) or P02 (biggest no-brainer bug),
see how Mario responds, then proceed.

## What to NOT upstream

- F-series patches (specialized to fork)
- Anything touching `data/system_prompt.txt` content beyond P04 (Mario's voice/style decisions)
- Anything that changes default behavior in a way users would notice unless it's a clear bug fix

## Working state of patches

| ID | Status | File |
|---|---|---|
| P01 | drafted | `patches/P01-text-leak-detector.md` |
| P02 | drafted | `patches/P02-prompt-truncation-fix.md` |
| P03 | drafted | `patches/P03-example-augmented-tools.md` |
| P04 | drafted | `patches/P04-led-vocab-disambiguation.md` |
| P05 | drafted | `patches/P05-serial-send-description.md` |
| P06 | pending | `patches/P06-config-wiring.md` |
| F01 | pending | `patches/F01-ollama-defensive-opts.md` |

(Patches drafted before the actual fork exists are preserved here as Markdown
with embedded diffs. When `WhitneyDesignLabs/WireClaw` is created, they get
transplanted into proper commits.)
