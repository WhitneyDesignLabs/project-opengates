# P06: Wire up unused `max_tokens` and `temperature` config fields

**Bucket:** Upstream PR candidate
**Impact:** Medium — currently the user has no way to lower temperature for tool-calling reliability, even though `config.json` and the web portal pretend they can
**Risk:** Low — defaults preserved
**Affected files:** `data/config.json.example`, `src/main.cpp`, `src/llm_client.cpp`, `include/llm_client.h`

## Problem

`data/config.json.openrouter.example` and `data/config.json.ollama.example` both contain `max_tokens` and `temperature` keys. The web config portal exposes them as editable. The C-side config loader (`src/main.cpp`) reads them into `cfg_max_tokens` and `cfg_temperature`. None of that matters because `LlmClient::buildRequest()` at `src/llm_client.cpp:319-320` hardcodes them:

```c
w += snprintf(buf + w, buf_len - w,
    ",\"max_tokens\":2048,\"temperature\":0.7}");
```

For tool-calling reliability with small local models, dropping temperature to 0.1-0.3 is a well-known reliability boost. Today there is no way to make that happen, even with full root access to the chip's filesystem.

## Solution

Plumb the config values through `LlmClient::begin()` (or add setters) and use them in `buildRequest()`.

## Diff

### `include/llm_client.h`

```diff
@@ class LlmClient {
 public:
     LlmClient();
 
-    void begin(const char *api_key, const char *model, const char *base_url = nullptr);
+    void begin(const char *api_key, const char *model, const char *base_url = nullptr,
+               int max_tokens = 2048, float temperature = 0.7f);
+
+    void setMaxTokens(int max_tokens) { m_max_tokens = max_tokens; }
+    void setTemperature(float t)      { m_temperature = t; }
@@ private state
+    int   m_max_tokens;
+    float m_temperature;
```

### `src/llm_client.cpp`

```diff
 void LlmClient::begin(const char *api_key, const char *model,
-                      const char *base_url) {
+                      const char *base_url, int max_tokens, float temperature) {
     ...
+    m_max_tokens  = (max_tokens  > 0) ? max_tokens  : 2048;
+    m_temperature = (temperature > 0.0f && temperature <= 2.0f) ? temperature : 0.7f;
 }
@@ in buildRequest
-    w += snprintf(buf + w, buf_len - w,
-        ",\"max_tokens\":2048,\"temperature\":0.7}");
+    w += snprintf(buf + w, buf_len - w,
+        ",\"max_tokens\":%d,\"temperature\":%.2f}",
+        m_max_tokens, m_temperature);
```

### `src/main.cpp`

In `setup()` or wherever `llm.begin(...)` is called, pass the config values through. Look up the actual call site:

```diff
-    llm.begin(cfg_api_key, cfg_model, cfg_api_base_url);
+    llm.begin(cfg_api_key, cfg_model, cfg_api_base_url,
+              cfg_max_tokens, cfg_temperature);
```

## Test plan

1. Set `max_tokens=512, temperature=0.2` in `/config.json`, reboot.
2. Trigger a chat. Capture the request body via serial debug (or wireshark on the LAN side).
3. Confirm the request body contains `"max_tokens":512,"temperature":0.20`.
4. Run a Mode-B-heavy test (long-subject NATS register). Lower temperature should improve argument fidelity slightly.

## Upstream PR text

```
Title: Wire up max_tokens and temperature from config

Background:
config.json.ollama.example and config.json.openrouter.example both have
max_tokens and temperature fields. The web config portal exposes them as
editable. cfg_max_tokens and cfg_temperature are populated by the loader.
But buildRequest() hardcodes both values to 2048 and 0.7. So setting them
in config does nothing.

This matters most for local-LLM users running tool-calling workloads,
where lowering temperature to 0.1-0.3 is a standard reliability lever.
Today there's no way to apply that lever even with full filesystem access.

Change:
- Add max_tokens and temperature parameters to LlmClient::begin().
- Store as members; use in buildRequest() instead of literals.
- Defaults preserved when zero/invalid values supplied.

Backwards-compatible: existing call sites that pass just (api_key, model,
base_url) get the same hardcoded defaults via parameter defaults.
```
