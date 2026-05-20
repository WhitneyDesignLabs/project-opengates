# P05: serial_send description clarifies who appends the newline

**Bucket:** Upstream PR candidate (smallest, friendliest first-PR candidate)
**Impact:** Low — recovers T19 on opengates-agent and qwen3:8b
**Risk:** Trivial — one-line description edit
**Affected files:** `src/tools.cpp`

## Problem

The `serial_send` tool description (`src/tools.cpp:110`) currently reads:

```json
{"name":"serial_send","description":"Send text over serial_text UART",
 "parameters":{"type":"object","properties":{
   "text":{"type":"string","description":"Text to send (newline appended)"}
 },"required":["text"]}}
```

The `"newline appended"` clause is meant to inform the caller that the firmware appends `\n` automatically (which it does, in `src/serial_text.cpp`). But the wording can be parsed two ways:

1. **As intended:** "we'll append a newline for you; just give us the text"
2. **As misread:** "your text should have a newline appended to it"

Two of five tested models (opengates-agent:v1, qwen3:8b) on T19 ("Send GET_TEMP to the Arduino over serial") emit `text="GET_TEMP\n"` rather than `text="GET_TEMP"`. The firmware then appends its own `\n`, producing a double-newline `"GET_TEMP\n\n"` on the wire. This is harmless to most Arduino sketches but is a genuine wire-protocol deviation, and downstream code that does line-buffered parsing may see an empty line after every command.

## Solution

Rewrite the description to remove the ambiguity. Optionally add a short example.

## Diff

### `src/tools.cpp`

```diff
@@ at line ~110 (serial_send tool definition)
-{"type":"function","function":{"name":"serial_send","description":"Send text over serial_text UART","parameters":{"type":"object","properties":{"text":{"type":"string","description":"Text to send (newline appended)"}},"required":["text"]}}},
+{"type":"function","function":{"name":"serial_send","description":"Send text over serial_text UART. The firmware appends a newline automatically; do not include one.","parameters":{"type":"object","properties":{"text":{"type":"string","description":"Text payload only. No trailing newline. Example: 'GET_TEMP', not 'GET_TEMP\\n'."}},"required":["text"]}}},
```

(Two edits: the top-level `description` clarifies who appends the newline; the `text` parameter `description` adds an explicit example showing what NOT to do.)

## Test plan

1. Rerun bench. T19 should flip to PASS on opengates-agent:v1 and qwen3:8b.
2. No other tests touch serial_send, so no regression risk elsewhere.

## Upstream PR text

```
Title: Clarify serial_send description to prevent model from appending \n

Background:
serial_send's description says "Text to send (newline appended)". This is
intended to inform the caller that the firmware appends \n, but parses
ambiguously -- some models interpret it as "your text should have a
newline appended to it" and emit text="GET_TEMP\n" instead of
text="GET_TEMP". The firmware then appends its own \n, producing
"GET_TEMP\n\n" on the wire.

Harmless on most Arduino sketches but breaks line-buffered downstream
parsers and is a genuine wire-protocol deviation. Bench evidence:
opengates-agent:v1 and qwen3:8b both leak \n into the text argument on
"Send GET_TEMP to the Arduino over serial".

Change:
Description now reads: "Send text over serial_text UART. The firmware
appends a newline automatically; do not include one." Plus an explicit
example in the text parameter description showing the wrong shape.

One-line semantic edit, no code logic touched.
```
