## `serial_send` description: ambiguous "newline appended" wording

Hi! I've been benchmarking WireClaw against a few small local LLMs (8B-class models on Ollama) and noticed an ambiguous bit of wording in the `serial_send` tool description that makes some of them produce subtly wrong output.

The current description (in `src/tools.cpp`):

```
"Send text over serial_text UART"
  text: "Text to send (newline appended)"
```

The `(newline appended)` clause is meant to inform the caller that **the firmware appends `\n` automatically** — and it does, in `src/serial_text.cpp`. But two of the five 8B models I tested parse the wording the other way: as "the text you provide should already have a newline appended to it." They emit `text="GET_TEMP\n"` instead of `text="GET_TEMP"`. The firmware then appends its own `\n`, putting `"GET_TEMP\n\n"` on the wire.

Bench evidence: in a 22-test tool-calling suite where the prompt is `"Send GET_TEMP to the Arduino over serial."`, both `opengates-agent:v1` and `qwen3:8b` emit the trailing `\n`. The other three models (`specialagentpuddy:8b`, `qwen3-nothinker`, and one custom variant) get it right. So the description's intended meaning lands for some models and not others.

Mostly harmless on Arduino sketches that ignore extra newlines, but a real wire-protocol deviation that breaks line-buffered downstream parsers (e.g. anything doing `Serial.readStringUntil('\n')` then trimming).

### Proposed fix

Rewrite the description to remove the ambiguity, and add an explicit example in the `text` parameter showing what NOT to do:

> "Send text over serial_text UART. The firmware appends a newline automatically; do not include one."
> `text`: "Text payload only. No trailing newline. Example: `'GET_TEMP'`, not `'GET_TEMP\n'`."

One-line edit in `src/tools.cpp`. No code-logic change. Happy to send a PR if this is something you'd be open to taking — let me know either way.
