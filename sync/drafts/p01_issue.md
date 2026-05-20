## LLM response parser silently passes prose-leaked tool calls to history

Hi again — second find from the same benchmarking work that produced #12. This one is more substantive than the `serial_send` description tweak; flagging as an issue first to see if it's something you'd want a PR for.

### What the parser does today

`LlmClient::parseToolCalls()` looks for the literal string `"tool_calls"` in the response body. If absent, it returns 0 tool calls. The caller in `parseResponse()` then falls through and treats the body's `content` field as a plain assistant text answer. That text becomes the chip's response to the user AND gets saved to `/history.json` for the next turn.

This is correct for clean OpenAI-format responses (Gemini, GPT, Claude via OpenRouter). But several local 8B-class models on Ollama emit tool-call intent as **prose in the content field** instead of populating `tool_calls`. Three patterns observed empirically:

1. **XML markers** like `<tool_call>{...}</tool_call>` — Hermes, Qwen-Instruct fine-tunes
2. **Fenced JSON code blocks** with tool-call-shaped keys
3. **Naked JSON** like `{"name": "rule_create", "parameters": {"condition":"always", ...}}` directly in prose

In all three cases the chip silently does nothing — the tool never fires. Worse, the leaked content gets saved to history, which reinforces the pattern on subsequent turns. Once a session goes into "model leaks tool calls in prose" mode, it tends to stay there until `/clear`.

### Empirical capture

Hardware-side reproduction during a tool-calling probe (2026-05-12, llama3.1:8b on Ollama):

User sent: "Every 5 minutes, send me the chip temperature on Telegram."

Agent loop iterations:
1. Model called `rule_create` missing `sensor_name` → chip returned an error
2. Model retried, missing `rule_name` → chip returned an error
3. Model self-corrected and emitted the complete call as naked JSON in the content field — NOT in `tool_calls`. The chip parsed nothing, saved the prose to history, and surfaced the prose back to the user. The user thought their periodic rule was set up. It wasn't.

This is a real silent-failure mode that's basically impossible to debug from the user side.

### Proposed fix

Add a content-side detector after `parseToolCalls()` returns 0: scan the content for the three pattern shapes above using simple `memmem()` substring matching. On hit, set a new `prose_leak_detected` flag, log the leak to Serial, and let the agent loop drop the content from history while surfacing a friendly retry prompt to the user ("Sorry, the model responded incorrectly. Please rephrase the request.").

Implementation is ~65 lines across `src/llm_client.cpp`, `include/llm_client.h`, and `src/main.cpp`. No regex (memmem only — fits ESP32 footprint). Includes a boot-time self-test (`llmSelfTestProseLeak`) that runs four representative cases at every boot and prints PASS/FAIL to Serial, so the detector's behavior is verifiable without a separate test harness.

Larger change than #12, but tightly scoped to the leak-detection path. Happy to send a PR with the implementation if this is something you'd want to take, and to walk through any of the design choices (which patterns to catch, what error message to show the user, etc.).
