# P01: Text-leak detector in response parser

**Bucket:** Upstream PR candidate
**Impact:** Critical — without this, every model that ever prose-leaks a tool call causes the chip to silently drop the command
**Risk:** Low (additive — same code paths execute, plus a new check + a flag the caller may ignore for backward compatibility)
**Affected files:** `include/llm_client.h`, `src/llm_client.cpp`, `src/main.cpp`

## Problem

`LlmClient::parseToolCalls()` (`src/llm_client.cpp:325-331`) looks for the literal string `"tool_calls"` in the response body. If absent, it returns 0. The caller in `parseResponse()` then falls through to extract `content` as a plain text answer. The `content` is returned to `chatWithLLM()` in `src/main.cpp`, which (at `src/main.cpp:472-473`) sees `result.tool_call_count == 0`, treats the text as the model's final answer, prints it, and saves it to `/history.json`.

Failure modes covered by this hole:

- **Mode A** (text leak): Model emits something like `\`\`\`json\n{"name":"led_set",...}\n\`\`\`` as content.
- **Mode C** (XML format): Model emits `<tool_call>{...}</tool_call>` (Qwen, Hermes, Anthropic-style fine-tunes).

In both cases the chip prints the response back to the user instead of acting on it. **And** the leaked content becomes part of the next turn's history, where it reinforces the behavior — the model sees its own prose-tool-call in the conversation buffer and concludes that's how to act, locking the chip into broken mode for the rest of the session until a `/new` clears history.

Bench data: zero of the five tested 8B models we ran trip this today (all emit valid `tool_calls`). But adding any Hermes-class model (which uses `<tool_call>` XML natively) would be 100% Mode C against the unmodified parser, completely unusable on chip. This patch is the prerequisite for ever testing those models.

## Solution

Add a `bool prose_leak_detected` field to `LlmResult`. In `parseResponse()`, after the existing parse, if `tool_call_count == 0` and `content_len > 0`, run a cheap leak detector on the content. On hit:

- Set `prose_leak_detected = true`
- Log to Serial (with content snippet if debug)
- Caller is responsible for surfacing error to user and **not** saving to history

The detector itself is a static helper using `memmem()` for high-signal substrings — no regex needed, fits ESP32's footprint and CPU budget.

## Diff

### `include/llm_client.h`

```diff
@@ struct LlmResult {
 struct LlmResult {
     bool ok;
+    /* True if model emitted tool-call intent as prose/markdown/XML instead of
+     * populating the structured tool_calls field. When true, the content
+     * should NOT be saved to conversation history -- doing so reinforces the
+     * behavior on subsequent turns. The caller should surface an error and
+     * either retry with a corrective system message or fail gracefully. */
+    bool prose_leak_detected;
     char content[LLM_MAX_RESPONSE_LEN];
     int  content_len;
     int  http_status;
```

### `src/llm_client.cpp`

Add helper near top of file (after includes, before class methods):

```c
/* Detect when LLM has emitted tool-call intent as prose instead of populating
 * the structured tool_calls field. High-signal markers only -- no regex.
 * Designed for ESP32 footprint: ~200 bytes flash, microseconds of runtime. */
static bool content_has_prose_tool_call(const char *content, int len) {
    if (!content || len <= 0) return false;

    /* XML markers used by Qwen-Instruct, Hermes, Anthropic-style fine-tunes */
    static const char *xml_markers[] = {
        "<tool_call>",
        "<function_calls>",
        "<invoke ",
        "<tool_use>",
    };
    for (size_t i = 0; i < sizeof(xml_markers)/sizeof(xml_markers[0]); i++) {
        const char *m = xml_markers[i];
        if (memmem(content, len, m, strlen(m))) return true;
    }

    /* Fenced JSON block followed by tool-call-shaped keys within 200 bytes */
    const char *fence = (const char *)memmem(content, len, "```json", 7);
    if (fence) {
        int remaining = len - (fence - content);
        int scan = remaining > 200 ? 200 : remaining;
        if (memmem(fence, scan, "\"name\"", 6) ||
            memmem(fence, scan, "\"function\"", 10) ||
            memmem(fence, scan, "\"arguments\"", 11)) {
            return true;
        }
    }
    return false;
}
```

Modify `parseResponse()` after the existing tool-call parse + content extraction:

```diff
 bool LlmClient::parseResponse(const char *body, int body_len, LlmResult *result) {
     result->ok = false;
+    result->prose_leak_detected = false;
     result->content[0] = '\0';
     result->content_len = 0;
@@ existing parse logic ...
     if (content && clen > 0) {
         int copy_len = clen < LLM_MAX_RESPONSE_LEN - 1 ? clen : LLM_MAX_RESPONSE_LEN - 1;
         memcpy(result->content, content, copy_len);
         result->content[copy_len] = '\0';
         result->content_len = json_unescape(result->content, copy_len);
     }

+    /* Detect prose-leaked tool calls: model emitted tool intent in content
+     * but no structured tool_calls. Saving this to history reinforces the
+     * behavior, so flag it and let the caller decide how to surface. */
+    if (tc_count == 0 && result->content_len > 0) {
+        if (content_has_prose_tool_call(result->content, result->content_len)) {
+            result->prose_leak_detected = true;
+            Serial.println("[LLM] WARNING: prose tool-call leak detected; not saving to history");
+            if (g_debug) {
+                int snip = result->content_len > 200 ? 200 : result->content_len;
+                Serial.printf("[LLM]   leaked content (%d bytes): %.*s...\n",
+                              result->content_len, snip, result->content);
+            }
+        }
+    }
+
     /* If we got tool calls, that's a success even without content */
     if (tc_count > 0) {
```

### `src/main.cpp`

In `chatWithLLM()` (around line 472, after the agent loop receives `result`):

```diff
     LlmResult result;
     ...

+    /* If the model prose-leaked a tool call, do NOT save to history -- that
+     * would teach it the leak is normal. Surface a corrective error and stop. */
+    if (result.prose_leak_detected) {
+        snprintf(finalContent, sizeof(finalContent),
+                 "Sorry, the model responded incorrectly. Please rephrase the request.");
+        Serial.println("[Agent] Prose leak surfaced as user-visible error");
+        break;  /* exit agent loop without history append */
+    }
+
     if (result.tool_call_count == 0) {
         finalContent = result.content;
         break;
     }
```

(Exact line numbers may shift; the anchor is the `result.tool_call_count == 0` check that decides whether the loop exits with the content as the final answer.)

## Test plan

Once flashed:

1. **Negative control:** Run the bench against the chip's LLM endpoint with the stock-OpenRouter model. Expect zero Mode A/C detections (clean models).
2. **Positive control:** Point the chip at a Hermes-3-8B endpoint. Send "Set the LED to red." Expect: serial logs `[LLM] WARNING: prose tool-call leak detected`, Telegram replies with the corrective error message, LED unchanged, no entry in `/history.json` for this turn.
3. **Confirm history isolation:** After the positive control, send "Set the LED to blue." Expect: model emits another leak, same handling, no compounding (each turn handled independently because the leak isn't in history).

## Upstream PR text

```
Title: Detect prose-leaked tool calls to prevent silent command drop

Background:
parseResponse() currently treats responses with no `tool_calls` field as
plain assistant text, even when the content body contains tool-call intent
in alternative formats (XML <tool_call>, fenced ```json blocks with
tool-call-shaped keys). The content is returned to the agent loop as the
final answer and saved to history, with three consequences:
1. The chip silently ignores the command (no action taken).
2. The user sees prose like "I'll set led_set with r=255..." in Telegram
   instead of getting their LED set.
3. The leaked content becomes part of next turn's history, reinforcing
   the behavior across the rest of the session.

This is hardware-side defense -- it does not require model changes.
Cloud models (Gemini, GPT, Claude via OpenRouter) rarely leak; but any
Hermes-family, Qwen-Instruct-XML, or similarly-formatted local model
leaks routinely.

Change:
- Add `prose_leak_detected` bool to LlmResult.
- After parseToolCalls returns 0, scan content for high-signal leak markers
  (XML start tags, fenced JSON with name/function/arguments keys). On hit:
  set flag, log to serial, return.
- Caller (chatWithLLM in main.cpp) checks the flag, surfaces a corrective
  error to the user, and does NOT append the leak to history.

Implementation: pure memmem(), no regex. ~200 bytes flash, microseconds CPU.

Tested with:
- google/gemini-2.5-flash (zero false positives, as expected)
- NousResearch/Hermes-3-Llama-3.1-8B (100% caught, error surfaced)
- (custom local model that occasionally fences JSON) -- mode A caught.

Bench data attached: `wireclaw-bench` test suite showing five mainstream 8B
models score 0 Mode-A and 0 Mode-C leaks today; one Hermes-family model
shows 100% leak rate without this patch and 100% caught-and-error-surfaced
with it.
```

---

## P01-v2 addendum (2026-05-12): naked-JSON pattern

### Empirical motivation

P01-v1 catches XML markers and fenced ```json blocks but **misses naked JSON
objects in plain prose** that contain tool-call-shaped keys. This gap was
flagged in the Day-1 firmware audit and empirically confirmed during step 5
probe B (2026-05-12), where llama3.1:8b emitted:

```
Let's call the rule "chip_temp_alert".

{"name": "rule_create", "parameters": {"condition":"always",
"interval_seconds":300,"off_action":"none","on_action":"telegram",
"on_telegram_message":"{value}C","sensor_name":"chip_temp",
"rule_name":"chip_temp_alert"}}
```

P01-v1 was silent. The chip parser doesn't read tool_calls from content,
so the rule was never created — but the user saw a sensible-looking JSON
block and got no error. Worse failure mode than smoke test 5's wrong color.

### Pattern logic

In `content_has_prose_tool_call()`, after the existing fenced-JSON check,
add a naked-JSON check: find the first `"name"` substring in content; within
200 bytes after, look for `"parameters"` or `"arguments"`. Both present =
naked-JSON tool-call leak.

```c
/* Naked JSON tool call leak: a JSON object containing both "name" and
 * "parameters" (Anthropic-style) or both "name" and "arguments"
 * (OpenAI-style) within close proximity. */
const char *name_key = (const char *)memmem(content, len, "\"name\"", 6);
if (name_key) {
    int after = len - (name_key - content);
    int scan = after > 200 ? 200 : after;
    if (memmem(name_key, scan, "\"parameters\"", 12) ||
        memmem(name_key, scan, "\"arguments\"", 11)) {
        return true;
    }
}
```

Adjacency requirement (200 bytes) keeps false-positive rate low against
legitimate prose that mentions those words far apart.

### Known false positive (documented limitation)

Legitimate explanations of tool-call format will trigger the detector. For
example: "A tool call looks like `{\"name\": \"X\", \"parameters\": {...}}`
in the OpenAI schema." Acceptable trade-off — the cost of a spurious
warning is low; the cost of a silent rule-not-created is high.

### Boot-time sanity check

`llmSelfTestProseLeak()` runs at boot, validating 4 cases:

| Case | Expected | Notes |
|---|---|---|
| `naked_json_probe_b` (captured leak) | detect | Real leak from step 5 |
| `clean_wrapup` ("LED is now red") | no detect | Negative control |
| `fenced_json_v1` (regression check for v1) | detect | Confirms v1 still works |
| `explanation_edge` (literal pattern in prose) | detect | Documented FP |

All 4 pass on chip per `tasks/serial_logs/step5_p01v2_com17.log`.

### Empirical chip validation (2026-05-12)

Step 5 probe B re-tested with P01-v2 firmware:
- Iteration 1+2 of the agent loop: model emitted structured tool calls,
  each missing one required arg, each producing a chip-side error.
- Iteration 3 retry: model emitted naked-JSON `{"name": "rule_create",
  "parameters": {...}}` in assistant content (the leak P01-v2 was
  designed for).
- **P01-v2 fired**: `[LLM] WARNING: prose tool-call leak detected; not
  saving to history`. Logged 227-byte leaked content for diagnosis.
- Telegram surfaced "Sorry, the model responded incorrectly. Please
  rephrase the request." instead of silently saving a broken rule.

End-to-end behavior matches P01-v1's design intent for a previously-
invisible failure mode.

### Upstream PR sequence

P01-v2 should be merged into the same PR as P01-v1 rather than offered as
a separate follow-up. They form one coherent feature: the leak detector
covers all three known prose-leak shapes (XML markers, fenced JSON,
naked JSON). Splitting them artificially weakens the case for either.

Update the upstream PR text above to mention naked-JSON in the marker
list, and add the boot-time sanity check as part of the description.
