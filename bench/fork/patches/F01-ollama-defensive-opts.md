# F01: Defensive Ollama options (`stream:false`, `num_ctx`, `keep_alive`)

**Bucket:** Fork-only (WhitneyDesignLabs)
**Impact:** High locally — `keep_alive=24h` keeps the model loaded in VRAM, turning cold-start 60s+ requests into warm 15-30s requests. UX-defining for local LLM use.
**Risk:** Low — defensive options that Ollama tolerates; OpenRouter ignores
**Affected files:** `include/llm_client.h`, `src/llm_client.cpp`

## Problem

`buildRequest()` builds a minimal OpenAI-style chat-completions request:

```json
{"model":"...","messages":[...],"tools":[...],"tool_choice":"auto",
 "max_tokens":2048,"temperature":0.7}
```

This works against OpenRouter, but is missing several Ollama-friendly options:

- **`stream: false`** — explicitly disable streaming. Ollama defaults to non-streaming on the `/v1/chat/completions` endpoint, so this is defensive only. But: if a future Ollama version or a proxy in between flips the default, our `tool_calls` get silently dropped (Mode E from Scott's failure taxonomy). Belt + suspenders.
- **`options.num_ctx`** — Ollama's context window cap. Without this, Ollama uses its own default (currently 4096 on most models), which truncates our system prompt + tool definitions + history. Need to set to at least 8192 to fit our request comfortably.
- **`options.keep_alive`** — how long Ollama keeps the model loaded after the request. Default is 5 minutes. For an always-on chip making sporadic requests, 5 minutes means most requests pay the cold-start cost. Setting `24h` (or `-1` for forever) keeps the model warm.
- **`options.temperature`** — Ollama's `options.temperature` shadows the top-level `temperature` for `/v1/chat/completions`. We currently set the top-level only, which works, but explicit `options.*` is more reliable across Ollama versions.

This patch is fork-only because:

- OpenRouter ignores unknown fields gracefully but they're unnecessary cost on the request body.
- The "right" `num_ctx` and `keep_alive` values depend on the deployment (local vs cloud, single-user vs shared) — opinionated decisions.
- Upstream probably wants to stay vendor-neutral.

## Solution

Detect whether the endpoint looks like Ollama (via base_url heuristic: contains `:11434` or `/v1/chat/completions` without `openrouter.ai` or `api.anthropic.com`) and add Ollama-friendly options only in that case.

Cleaner alternative: add config flag `cfg_llm_provider` ∈ `{openrouter, ollama, anthropic}` and branch on that explicitly. Recommend the explicit flag.

## Diff

### Config

`data/config.json.example`:

```diff
   "api_base_url": "",
+  "llm_provider": "openrouter",
   "nats_host": "",
```

Values: `openrouter` (default), `ollama`, `anthropic`. Anything else falls back to a generic minimal request shape.

### `src/main.cpp` (config load)

```diff
+    jsonGetString(json_buf, "llm_provider", cfg_llm_provider, sizeof(cfg_llm_provider));
+    if (cfg_llm_provider[0] == '\0') strcpy(cfg_llm_provider, "openrouter");
```

### `src/llm_client.cpp`

```diff
 int LlmClient::buildRequest(char *buf, int buf_len, ...) {
     ...
     w += snprintf(buf + w, buf_len - w, "]");
     if (tools_json && tools_json[0]) {
         w += snprintf(buf + w, buf_len - w,
             ",\"tools\":%s,\"tool_choice\":\"auto\"", tools_json);
     }
     w += snprintf(buf + w, buf_len - w,
-        ",\"max_tokens\":%d,\"temperature\":%.2f}",
-        m_max_tokens, m_temperature);
+        ",\"max_tokens\":%d,\"temperature\":%.2f", m_max_tokens, m_temperature);
+
+    /* Provider-specific options */
+    if (strcmp(m_provider, "ollama") == 0) {
+        w += snprintf(buf + w, buf_len - w,
+            ",\"stream\":false"
+            ",\"options\":{"
+              "\"num_ctx\":%d,"
+              "\"temperature\":%.2f,"
+              "\"keep_alive\":\"%s\""
+            "}",
+            m_ollama_num_ctx, m_temperature, m_ollama_keep_alive);
+    }
+
+    w += snprintf(buf + w, buf_len - w, "}");
```

Add corresponding setters and members. Default `m_ollama_num_ctx = 8192`, `m_ollama_keep_alive = "24h"`.

## Test plan

1. Set `llm_provider=ollama` in config.
2. Capture an outbound request body via serial debug. Confirm `stream:false`, `options.num_ctx:8192`, `options.keep_alive:"24h"` are present.
3. Cold-start measurement: send first request after a fresh `ollama stop`. Time it (expect 30-60s).
4. Warm followup: send second request. Time it (expect 15-25s). Repeat 30 minutes later — should still be warm with `keep_alive=24h`.
5. OpenRouter regression: switch `llm_provider=openrouter`, confirm no `options` block in the request body, confirm requests still succeed.

## Test results (to record after running)

| Metric | Before patch | After patch |
|---|---|---|
| Cold-start latency (first request) | TBD | TBD |
| Warm latency (5m later) | TBD | TBD |
| Warm latency (30m later, with keep_alive=24h) | TBD | TBD |
| Context truncation seen (Ollama auto num_ctx) | TBD | should be N/A |
