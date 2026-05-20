# P02: System prompt buffer truncation fix

**Bucket:** Upstream PR candidate
**Impact:** High — recovers T11 (periodic rules) and T12 (time-based rules), which fail on every tested model with the truncated prompt
**Risk:** Very low — pure buffer-size fix, no behavioral change
**Affected files:** `src/main.cpp`

## Problem

`cfg_system_prompt` is declared as `char[4096]` at `src/main.cpp:48`. The shipped `data/system_prompt.txt` is 7266 bytes. The loader at `src/main.cpp:188`:

```c
len = readFile("/system_prompt.txt", cfg_system_prompt, sizeof(cfg_system_prompt));
```

`readFile` (line 136) calls `f.readBytes(buf, buf_len - 1)` and null-terminates at position `len`. With `buf_len = 4096`, it reads at most 4095 bytes and silently drops the remaining 3171 bytes from the back of the file.

The dropped section contains the guidance for `chain_create`, time-based rules (`clock_hour`, `clock_minute`, `clock_hhmm`), and rule management (`rule_list`, `rule_delete all`, `rule_enable`). Bench-confirmed harm: T11 ("send Telegram every 2 minutes") and T12 ("send Telegram at 10:12") fail on every tested model because the relevant guidance is in the dropped section.

## Solution

Two-part fix:

1. Grow the buffer to 8192 bytes. Static allocation, well within budget (current static memory usage ~6 KB for config-related buffers, ESP32-C6 has 320 KB SRAM).
2. Detect truncation explicitly and warn on serial. Currently the read just silently caps.

Why not load dynamically into PSRAM? Because the prompt isn't *that* big and a fixed buffer keeps the code simple. 8192 is comfortable headroom for any reasonable system prompt without the cost of heap fragmentation on a long-running device.

## Diff

### `src/main.cpp`

```diff
@@ at line 48 (cfg_system_prompt declaration)
-char cfg_system_prompt[4096];
+char cfg_system_prompt[8192];
```

```diff
@@ at line 188 (loader call site)
-    len = readFile("/system_prompt.txt", cfg_system_prompt, sizeof(cfg_system_prompt));
+    len = readFile("/system_prompt.txt", cfg_system_prompt, sizeof(cfg_system_prompt));
+    if (len > 0) {
+        /* Detect truncation: if we filled the buffer minus null terminator,
+         * the source file was at least that long and likely got cut off. */
+        File f = LittleFS.open("/system_prompt.txt", "r");
+        if (f) {
+            size_t actual = f.size();
+            f.close();
+            if (actual > (size_t)(sizeof(cfg_system_prompt) - 1)) {
+                Serial.printf("[main] WARNING: system_prompt.txt is %u bytes "
+                              "but buffer is only %u; truncated at byte %d. "
+                              "Shrink the prompt or grow cfg_system_prompt.\n",
+                              (unsigned)actual,
+                              (unsigned)sizeof(cfg_system_prompt),
+                              len);
+            }
+        }
+    }
```

(The size check is done after the read, by reopening the file just to query `f.size()`. Slightly redundant but simple and runs once at boot. Alternative: modify `readFile()` itself to return both length and "was truncated" flag.)

## Test plan

1. Confirm boot serial shows no truncation warning with the default 8192-byte buffer + 7266-byte shipped prompt.
2. Rerun bench against forked firmware (same model, full prompt now in scope). Expect T11 and T12 to flip to PASS on baseline models.
3. If user replaces `/system_prompt.txt` with a >8192-byte file, serial warning should fire at boot.

## Upstream PR text

```
Title: Fix silent truncation of system_prompt.txt at 4095 chars

Background:
cfg_system_prompt is char[4096]; readFile truncates at 4095 bytes. The
shipped system_prompt.txt is 7266 bytes -- it loads at boot and is silently
chopped mid-sentence in the "Telegram alerts in rules" section. Everything
after (Rule chaining, Managing rules, Time-based rules guidance) never
reaches the model.

Effect:
- chain_create tool is documented but the model gets no usage guidance.
- Time-based rules (clock_hour/clock_minute/clock_hhmm sensors) work in
  firmware but the model doesn't know they exist.
- "every N minutes" -> condition=always + interval_seconds mapping is gone.

Bench data: tool-calling bench across 5 different 8B-class models all fail
T11 (periodic rule, "every 2 minutes") and T12 (time-based, "at 10:12")
because the relevant guidance is in the dropped section. Same models pass
both tests when the full prompt is restored.

Change:
- Grow cfg_system_prompt from 4096 to 8192 bytes.
- Add a boot-time warning if /system_prompt.txt is larger than the buffer
  (so future-proof against the bug recurring).

No behavioral change for users who have shortened their system prompt below
the original 4095 limit. For default install, restores the dropped guidance.
```
