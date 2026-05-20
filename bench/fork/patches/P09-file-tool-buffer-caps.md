# P09: Expand `file_write` / `file_read` content buffers and add append mode

**Bucket:** Upstream PR candidate (independent of P06/P08; touches different code paths)
**Impact:** Medium — current caps make Telegram-mediated config / prompt / memory inspection AND mutation infeasible at realistic sizes
**Risk:** Low — buffer expansion plus an optional `mode` parameter; no breaking changes
**Affected files:** `src/tools.cpp` (tool_file_write, tool_file_read), `data/system_prompt.txt` (tool descriptions if mode parameter is added)
**Status:** Drafted, not implemented.

## Problem

Two paired pathologies in the existing file tools, both discovered during 2026-05-12 step-4 work:

### (a) `tool_file_write` has a 512-byte content cap and no append mode

[`tool_file_write` at src/tools.cpp:195-224](src/tools.cpp:195):

```c
static void tool_file_write(const char *args, char *result, int result_len) {
    char path[64];
    char content[512];   // <-- HARD CAP

    ...
    /* Protect config.json from being overwritten */
    if (strcmp(path, "/config.json") == 0) { ... return; }
    if (!jsonArgString(args, "content", content, sizeof(content))) { ... }

    File f = LittleFS.open(path, "w");   // <-- ALWAYS TRUNCATES
    ...
    f.print(content);
    ...
}
```

Consequences:
- Operators cannot push a new `system_prompt.txt` (typical ~7-8 KB) via Telegram. Any file_write would corrupt it.
- The chip's own LLM cannot meaningfully self-modify any non-trivial file. Day-1's "remember my favorite color is purple" works because the content is <30 bytes, but anything bigger fails.
- This blocked step 4 from using the `file_write` route to deploy P04's new system prompt; we had to do a full `uploadfs` instead, which wiped LittleFS.

### (b) `tool_file_read` has a 512-byte content cap

Similar issue, observed when inspecting `/config.json` over Telegram during step 2 of the bisect: the returned content was silently truncated mid-string. The truncation hid the trailing portion of the `api_base_url` field, which (when we tried to recover from a Day-1 captive-portal reset on 2026-05-12) led us to enter an incomplete URL and produce an `[ERROR] LLM call failed: TCP connect failed` on the first reconfig attempt. Cost about 5 minutes of session time to diagnose.

This is an active operator hazard, not just a future-feature gap.

### Why not roll into P08

P08 (write-side completeness for `max_tokens`/`temperature`) is about extending the config-write paths (HTTP POST and captive portal). P09 is about the LLM tool buffers in `src/tools.cpp`. Different files, different review surfaces, different reviewer audiences. Ship separately.

## Solution sketch

Three related fixes, any combination of which closes the gap:

### (i) Expand the content buffers

Raise both `tool_file_write`'s and `tool_file_read`'s content buffers from 512 to (say) 8192 bytes. The chip has ample heap for this (~150 KB free after boot). The tool's args JSON is itself bounded by the LLM's max-token output, so we're not opening an unbounded sink.

Open question for implementation: is 8192 safe across the existing call paths (no stack overflow for the static arrays)? Worth verifying by quick build.

### (ii) Add an `append` mode to `tool_file_write`

Add an optional `"mode"` field to the tool's JSON schema. Default = "write" (current behavior — truncate-and-write). New = "append" (open with `"a"`). Lets the LLM build large files iteratively if needed.

Update the tool description in the system prompt with a short example showing both modes.

### (iii) Add an `offset` parameter to `tool_file_read`

For files exceeding the buffer, allow paginated reads via `{"path": "/foo.json", "offset": 0, "length": 4096}` style args. Cleaner than just upping the buffer for very large files (e.g., a future >8KB system_prompt).

## Test plan

1. Apply (i) and (ii) on a clean branch off P04 (or step 4 if step 4 ships). Build, flash.
2. Via Telegram: ask the chip to write a multi-KB string to `/test_large.txt`. Confirm via subsequent file_read that the content landed correctly.
3. Via Telegram: ask the chip to append a string to an existing file. Confirm growth.
4. Via Telegram: read `/config.json` (or any other ~600+ byte file). Confirm no truncation.
5. With (iii) applied: read `/system_prompt.txt` with offset=4096, length=4096. Confirm second-half bytes return correctly.

## Upstream-ability

Yes. The 512-byte caps look like first-cut conservative defaults that haven't been revisited. The append-mode addition is a small ergonomics win that doesn't change existing behavior (default stays "write"). Should be acceptable upstream.

## Discovery context

Both halves of this patch were discovered during the 2026-05-12 step-4 prep and execution:
- (a) when planning P04 deployment, we needed to push a 7904-byte system_prompt.txt via LLM file_write and found the 512-byte cap blocking us
- (b) during captive-portal reconfig recovery, the `/config.json` content we had on file (from step 2 file_read) had been silently truncated, masking the api_base_url path component

See [sync/from_code.md](../../../sync/from_code.md) (2026-05-12 step 4 handback) for the operational sequence.

## Related patches

- **P06** (config wiring) — read-side wires `max_tokens`/`temperature`; needs P08 to make those settable from operator side
- **P08** (config write-side) — extends `/api/config` POST and captive portal write paths to 14 keys
- **P09 (this patch)** — extends file_write/file_read buffer caps and adds modes

P06 + P08 + P09 together close the loop on operator-accessible runtime config and file-tool capability for the WireClaw fork.
