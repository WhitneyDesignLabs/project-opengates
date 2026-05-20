# P11: `use_modelfile_system` config flag to skip API system messages

**Bucket:** Upstream PR candidate
**Impact:** Medium — required for operators running custom Ollama models with baked-in `SYSTEM` directives; no behavior change when off
**Risk:** Low — default false preserves stock behavior; backwards-compatible at the call-site API and the on-wire body
**Affected files:** `data/config.json.example`, `src/main.cpp`, `src/llm_client.cpp`, `include/llm_client.h`

## Problem

When an operator builds a custom Ollama model — for example, a Modelfile-baked variant with a constitutional `SYSTEM` directive and tuned `PARAMETER` block — WireClaw's chat handler silently overrides it. The chat-completions API contract is "if the request body contains `role:"system"` entries, the model uses those instead of the Modelfile `SYSTEM`." WireClaw currently always prepends `cfg_system_prompt` (from `data/system_prompt.txt`) as the first `role:"system"` message, and optionally a second `role:"system"` entry derived from `/memory.txt`. Both of these silently displace the baked `SYSTEM` on every call.

Empirical witness: on this project's bench (May 2026), `opengates-agent:v1` (a constitutional Modelfile bake of `qwen3:8b`) scored 20/22 in direct curl testing but only matched `qwen3:8b` stock (19/22) when called through WireClaw — a tie indistinguishable from "baked SYSTEM had no effect." `PROJECT_STATUS.md` "Critical integration finding — Modelfile SYSTEM is bypassed by WireClaw" documents this.

The fork-tree analogue of the upstream pattern is the "Gatekeeper framework" recommendation from `baking-constitutional-models-8gb-vram.md` §8: a lean wrapper that sends only what the model needs, letting the bake do its job. P11 is that toggle on the WireClaw side.

## Solution

Add a `use_modelfile_system` boolean to `config.json`. When true, `LlmClient::buildRequest()` filters out any message with `role == "system"` from the outbound `messages` array, letting the baked `SYSTEM` directive apply on the Ollama side instead.

Design choices:

- **Filter at emit time, not at call site.** The conditional sits inside `LlmClient::buildRequest()` rather than around each `llmMsg("system", ...)` line in `main.cpp`. Single point of truth — any future caller that adds a `role:"system"` message is automatically affected by the flag. Mirrors P06's clean-isolation pattern (cfg values reach the `LlmClient` through a setter, not via globals reached into).
- **Skip ALL `role:"system"` entries, not just the system_prompt.** WireClaw today injects two such entries: `cfg_system_prompt` (the v4 compact prompt) and a `/memory.txt` dump. Both displace the baked `SYSTEM`. P11 suppresses both — the baked model is expected to fetch memory via explicit `file_read` tool calls instead.
- **Emit-time filter requires `emitted` counter.** The original loop used `if (i > 0)` to write the `,` separator. With messages skippable mid-loop, this produces malformed JSON (`[,{...}]`). The patch tracks emitted-message count separately so the separator stays valid.

The `tools` array is sent regardless of this flag. Tool definitions reach the model in either mode — the bake's job is to apply identity / policy / wrapping conventions, not to enumerate tools (the API does that).

## Diff

### `include/llm_client.h`

```diff
@@ class LlmClient {
 public:
     LlmClient();

     void begin(const char *api_key, const char *model, const char *base_url = nullptr);

+    /* Skip role:"system" messages on the wire. For baked-in Modelfile SYSTEM. */
+    void setSkipSystemMessages(bool skip) { m_skipSystemMessages = skip; }
+
@@ private state
     bool m_use_tls;
     char m_error[128];
+    bool m_skipSystemMessages = false;
```

### `src/llm_client.cpp` (filter inside `buildRequest()`)

```diff
     w += snprintf(buf + w, buf_len - w,
         "{\"model\":\"%s\",\"messages\":[", m_model);
     if (w >= buf_len) return -1;

+    int emitted = 0;
     for (int i = 0; i < count; i++) {
-        if (i > 0) {
+        if (m_skipSystemMessages && messages[i].role &&
+            strcmp(messages[i].role, "system") == 0) continue;
+        if (emitted > 0) {
             if (w + 1 >= buf_len) return -1;
             buf[w++] = ',';
         }
@@ end of for-loop body
         if (w >= buf_len) return -1;
+        emitted++;
     }
```

### `src/main.cpp`

```diff
@@ cfg globals
 int cfg_telegram_cooldown = 3;
+bool cfg_use_modelfile_system = false;

@@ configDefaults()
     strncpy(cfg_timezone, "UTC0", sizeof(cfg_timezone));
+    cfg_use_modelfile_system = false;

@@ loadConfig() JSON parser
         jsonGetString(json_buf, "timezone", cfg_timezone, sizeof(cfg_timezone));
+        char b_buf[8];
+        if (jsonGetString(json_buf, "use_modelfile_system", b_buf, sizeof(b_buf))) {
+            cfg_use_modelfile_system = (strcmp(b_buf, "true") == 0 ||
+                                        strcmp(b_buf, "1") == 0);
+        }

@@ setup()
     llm.begin(cfg_api_key, cfg_model, cfg_api_base_url);
+    llm.setSkipSystemMessages(cfg_use_modelfile_system);
```

### `data/config.json.example`

```diff
-  "timezone": "UTC0"
+  "timezone": "UTC0",
+  "use_modelfile_system": "false"
```

## Code locations (against upstream/main `ad84614`)

- `include/llm_client.h:71` — `setSkipSystemMessages` declaration; `include/llm_client.h:100` — `m_skipSystemMessages` member.
- `src/llm_client.cpp:247` — `int emitted = 0;`; `:249-250` — filter conditional; `:252` — `if (emitted > 0)` (was `if (i > 0)`); `:311` — `emitted++;`.
- `src/main.cpp:51` — `cfg_use_modelfile_system` global; `:66` — explicit default in `configDefaults()`; `:185-188` — JSON parser case in `loadConfig()`; `:1664` — `llm.setSkipSystemMessages()` call after `llm.begin()`.
- `data/config.json.example:13-14` — documentation parity.

Total: 18 added / 2 removed across 4 files.

## Test plan

Two firmware variants are required because the patch's two assertions need different tests.

### Test 1 & 2 (`p11-test` branch — flag default flipped to `true` for testing, + REQ_BODY debug printf cherry-picked from `bisect-step2-P06-formatfix@e9fd3bc`)

1. `/debug` ON via Telegram. `/clear` history. Send "Hello".
2. **Test 1 — byte-level proof.** Serial REQ_BODY dump expected: `{"model":"llama3.1:8b","messages":[{"role":"user","content":"Hello"}],"tools":[...]}`. No `role:"system"` entry anywhere in the body.
3. **Test 2 — behavioral consequence.** Send "What tools do you have available?". Model response expected: generic answer drawn from llama3.1:8b's training and prior tool-call results in history, NOT a WireClaw-tool-specific enumeration with `led_set` / `rule_create` / etc. names. (Model has CALLING ability via the still-sent `tools` array, but loses the system-prompt's knowledge framing.)

### Test 3 (`p11-use-modelfile-system` branch — default false, no REQ_BODY printf)

4. `/debug` ON. `/clear` history. Send "Set the LED to red."
5. **Test 3 — regression check.** Expect `led_set({"r":255,"g":0,"b":0})` tool call (or argument-order variant `{"b":0,"g":0,"r":255}`) followed by concise confirmation reply. Confirms default-off preserves stock behavior.

### Empirical results (chip on `192.168.1.27`, Ollama on `192.168.1.60:11434`, model `llama3.1:8b`)

| Test | Pass | Evidence |
|------|------|----------|
| 1 | ✓ | REQ_BODY 8795 bytes; messages array `[{"role":"user","content":"Hello"}]` only; filter survives the agentic loop's second iteration (REQ_BODY 9152 bytes after `device_info` tool call has 3 entries, still zero `role:"system"`) |
| 2 | ✓ | Model replied with categories drawn from prior `device_info` result ("Free heap, Total heap, Uptime, WiFi"), did NOT enumerate `led_set` / `rule_create` / WireClaw-specific tool names. REQ_BODY for multi-turn case has 3 message entries, still zero system messages. |
| 3 | ✓ | `led_set({"b":0,"g":0,"r":255})` fired correctly; reply "The onboard LED is now red." (concise, matches v4 prompt's style). Indirect evidence the system message is back: request grew from ~9KB (Tests 1/2) to **13,052 bytes** (≈ `cfg_system_prompt`'s 3999 bytes); prompt_tokens 3144 vs 2032 (Δ ≈ 1100 tokens ≈ system prompt at ~3.5 chars/token). |

The upstream-PR branch (`p11-use-modelfile-system`) does not carry the REQ_BODY debug printf — it's `p11-test`-only — so Test 3 byte-level proof is indirect (token delta + size delta). The pass criterion the directive specified ("tool call fires correctly with flag off") is met directly.

## Upstream PR text

```
Title: Add use_modelfile_system flag to skip API system messages

When operators run a custom Ollama model with a baked SYSTEM directive
(via Modelfile), WireClaw's client-side system prompt silently replaces
it on every chat completion request, defeating the bake. The
opengates-agent:v1 vs qwen3:8b bench tie (May 2026) was the empirical
witness: the baked model scored the same as the base model when called
through WireClaw, indistinguishable from "the baked SYSTEM had no
effect."

This patch adds a use_modelfile_system flag to config.json (string
"true"/"false", default false to preserve stock behavior). When true,
LlmClient::buildRequest() omits any message with role=="system" from
the outbound messages array, letting the baked SYSTEM directive apply
on the Ollama side.

The filter sits in buildRequest() rather than at the call site so any
caller's role:"system" messages are uniformly affected. In particular,
WireClaw injects two system entries today -- the cfg_system_prompt and
a /memory.txt-derived memory dump -- and the flag suppresses both
together. By design: a baked model is expected to fetch memory via
explicit file_read tool calls rather than via system-message injection.

Implementation:
- bool cfg_use_modelfile_system loaded from config.json (matches the
  jsonGetString + atoi pattern used for nats_port etc).
- LlmClient::setSkipSystemMessages() setter, called after llm.begin().
- buildRequest() tracks emitted message count separately from the
  loop index so the "," separator stays valid when entries are
  skipped (avoiding malformed "[,{user...}]" JSON).

Default off: existing operators see no behavior change. The tools
array is sent regardless of this flag, so tool definitions still
reach the model in either mode.
```

## Open questions for upstream

- **Flag location: config.json vs build-time `#define`?** Both work; config.json matches the existing pattern (`temperature`, `nats_port`, `telegram_cooldown` are all string-valued in config.json). Build-time `#define` would be smaller still but loses the runtime-toggleable property.
- **Boolean encoding: stringified `"true"`/`"false"` vs bare JSON boolean?** Patch uses stringified because `jsonGetString` is the existing extractor. A future `jsonGetBool` helper could replace this; out of scope for P11.
- **Web UI write-side:** the config-portal write path (`web_config.cpp`, `setup_portal.cpp`, `tool_file_write`) cannot today write the new field — same gap as P06's `max_tokens` / `temperature`. P08 (write-side completeness) is the cleanup; not required for P11 to ship.
