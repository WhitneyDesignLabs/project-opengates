Fixes #<ISSUE_NUMBER>

Small clarification to the `serial_send` tool description in `src/tools.cpp`. The previous wording (`"Text to send (newline appended)"`) is intended to mean "the firmware appends a newline for you" but parses ambiguously — some 8B-class models read it as an instruction to append `\n` themselves, producing a double-newline on the wire.

The new wording removes the ambiguity in the top-level description and adds an explicit "wrong shape" example in the `text` parameter description:

```
"Send text over serial_text UART. The firmware appends a newline automatically; do not include one."
  text: "Text payload only. No trailing newline. Example: 'GET_TEMP', not 'GET_TEMP\n'."
```

### Empirical impact

In a 22-test tool-calling bench across five 8B models, this resolves the `Send GET_TEMP to the Arduino over serial` failure on `opengates-agent:v1` and `qwen3:8b` (both previously emitted `text="GET_TEMP\n"`). No regression on the other three models or on any other test in the suite.

One file changed, one line modified. Offered as a small clarification — happy to revise wording or split into two PRs (top-level description vs parameter description) based on your preference.
