Fixes #<ISSUE_NUMBER>

Adds a content-side detector to `LlmClient::parseResponse()` that catches model responses where tool-call intent appears in assistant prose rather than the structured `tool_calls` field. The existing parser silently drops these, surfacing the prose to the user and saving it to `/history.json` — which reinforces the bad pattern on subsequent turns.

### What's caught

The detector matches three pattern shapes (all via `memmem()`, no regex):

- **XML markers**: `<tool_call>`, `<function_calls>`, `<invoke `, `<tool_use>` — Hermes / Qwen-Instruct fine-tunes
- **Fenced JSON code blocks** (```` ```json ````) containing tool-call-shaped keys (`"name"`, `"function"`, `"arguments"`) within 200 bytes of the fence
- **Naked JSON** with both `"name"` and (`"parameters"` OR `"arguments"`) keys within 200 bytes of each other — Anthropic-style and OpenAI-style structured-tool-call shapes

### Boot-time self-test

`llmSelfTestProseLeak()` runs four cases at every boot and prints PASS/FAIL to Serial:

1. A captured naked-JSON leak from a real probe — expects detect
2. A clean wrap-up like "I called led_set with r=255, g=0, b=0. The LED is now red." — expects no detect
3. A fenced-JSON case — regression check
4. A literal explanation of tool-call format ("a tool call looks like `{\"name\": \"X\"}`") — expects detect (documented false positive)

The false positive on case 4 is acknowledged by design: cost of a spurious warning is low; cost of a silent rule-not-created is high. Lets any operator verify the detector works without a separate test harness.

### Behavior on detect

- Set `prose_leak_detected = true` on `LlmResult`
- Log to Serial (with content snippet under `g_debug`)
- `chatWithLLM()` checks the flag, surfaces "Sorry, the model responded incorrectly. Please rephrase the request." to the user, and exits the agent loop without appending the leak to history

### Empirical impact

Resolves a real chip-side silent-failure mode captured 2026-05-12: llama3.1:8b on a periodic-rule prompt emitted naked JSON in content after two failed structured-tool-call iterations; without this PR the chip would have done nothing and the user would have seen prose claiming the rule was set up. With this PR the chip surfaces the corrective error.

138 lines added across `src/llm_client.cpp`, `include/llm_client.h`, and `src/main.cpp`. Pure additive — no behavior change for responses that don't trigger the detector. Happy to revise pattern logic, the user-facing error message, or split into multiple commits based on your preference.
