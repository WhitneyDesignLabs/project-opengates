# P08: Complete the write-side for `max_tokens` and `temperature`

**Bucket:** Upstream PR candidate (likely rolled into P06 or shipped as a P06 follow-up)
**Impact:** Medium — P06 added read-side wiring but no operator can actually set these fields at runtime without reflashing the data partition
**Risk:** Low — purely extends existing config-write paths to two additional keys
**Affected files:** `src/web_config.cpp`, `src/setup_portal.cpp`, `src/main.cpp` (serial handler), `src/web_config.cpp` HTML form (portal UI)
**Status:** Drafted, not implemented. Blocked by ongoing bisect work. Implementation deferred.

## Problem

P06 ([P06-config-wiring.md](P06-config-wiring.md)) added `cfg_max_tokens` and `cfg_temperature`, wired them through `LlmClient::begin()` → `m_temperature` → `buildRequest()`, and made the request body emit them at the wire level. Read-side end-to-end works (confirmed by serial-level inspection during the 2026-05-12 bisect work).

But P06 did **not** extend any of the four operator-facing write paths to actually let someone set these fields at runtime. Today the only ways to populate `temperature` in `/config.json` on a running chip require reflashing the data partition (`pio run -t uploadfs`), which destroys user `memory.txt` / `history.json`.

### The four blocked paths

1. **HTTP POST to `/api/config`** — [`handlePostConfig` at src/web_config.cpp:154](src/web_config.cpp:154) iterates a hardcoded 12-key array:

   ```c
   const char *keys[] = {
       "wifi_ssid", "wifi_pass", "api_key", "model", "device_name",
       "api_base_url", "nats_host", "nats_port", "telegram_token",
       "telegram_chat_id", "telegram_cooldown", "timezone"
   };
   ```

   Then writes a complete new `/config.json` containing exactly those 12 fields. Any `"temperature"` or `"max_tokens"` in either the POST body OR the existing file are silently dropped on every save.

2. **Captive-portal save** — [`saveConfig` at src/setup_portal.cpp:154](src/setup_portal.cpp:154) writes the same hardcoded 12-field shape and (as a separate bug worth flagging) resets `telegram_cooldown` to a hardcoded `"15"` on every save regardless of the existing value.

3. **Serial command** — [`handleSerialCommand` in src/main.cpp](src/main.cpp:1579) supports `/status /clear /heap /debug /devices /rules /reboot /config /prompt /history /setup`. There is no `/config set <key> <value>` or equivalent runtime mutator.

4. **`file_write` LLM tool** — [`tool_file_write` at src/tools.cpp:204](src/tools.cpp:204) has an explicit guard:

   ```c
   /* Protect config.json from being overwritten */
   if (strcmp(path, "/config.json") == 0) {
       snprintf(result, result_len, "Error: cannot overwrite config.json via tool");
       return;
   }
   ```

   The LLM is hard-blocked from writing to `/config.json`.

The net result: `cfg_temperature` is a runtime-only variable. Setting it requires recompiling with a different default (changing [src/main.cpp:68](src/main.cpp:68)) or reflashing the data partition. Neither is acceptable for a deployed device.

## Solution (sketch only — implementation deferred)

Three independent fixes, any combination of which closes the gap. Probably ship all three:

### (a) Extend `handlePostConfig` to 14 keys

Add `"max_tokens"` and `"temperature"` to the `keys[]` array in `handlePostConfig`. Same `wcJsonGetString` + masked-fallback pattern as the existing 12 fields. Single-block edit.

### (b) Extend captive-portal `saveConfig` similarly

Same change to `setup_portal.cpp:saveConfig`. While there, fix the `telegram_cooldown` hardcoded-reset bug as a drive-by (or split into a separate F-series patch — TBD).

### (c) Expose the fields in the web portal HTML form

The portal HTML form in `src/web_config.cpp` (around the existing input rows for `model`, `device_name`, etc.) should add two new inputs for `max_tokens` and `temperature` with reasonable validation hints (`temperature` should accept 0.0-2.0 floats, `max_tokens` integers ≥ 1). The corresponding `saveConfig()` JS already POSTs whatever fields are in the form, so adding inputs is purely an HTML change once (a) is in place.

### Optional (d): `/config set <key> <value>` serial command

Adds runtime mutability for all config keys, not just the two new ones. Useful for diagnostics. Could be a separate patch; not blocking.

## Test plan

1. Apply (a) + (b) + (c) on a fresh branch off P06.
2. From the web portal, set `max_tokens=512, temperature=0.2`. Save. Reboot.
3. Confirm `/config.json` contains both fields with the new values.
4. Trigger a chat. With `/debug` enabled, confirm the request body shows `"max_tokens":512,"temperature":0.2` at the wire level.
5. Power-cycle the chip. Confirm the fields survive reboot.
6. Repeat 2-5 via curl against `/api/config` directly (skipping the form UI), confirming the JSON shape the JS form produces is also accepted.

## Upstream PR text (draft)

```
Title: Allow setting max_tokens and temperature from the web portal

Background:
P06 wired max_tokens and temperature from config.json into the request
body, but did not extend any of the four config-write paths to let an
operator set these fields. /api/config POST and the captive portal both
write a complete config from a hardcoded 12-key array; the LLM
file_write tool has an explicit anti-overwrite guard on /config.json;
and there is no serial command to mutate config at runtime. So today
the fields are read-side-only — they work as defaults but operators
cannot set them.

Change:
- Extend handlePostConfig and setup_portal.cpp::saveConfig to include
  max_tokens and temperature in the write array.
- Add input fields for both to the web portal HTML.

Existing 12 fields untouched. Defaults still apply when fields are absent.
```

## Why this is upstream-able rather than fork-only

The patch completes a half-shipped feature that the upstream commit already advertised in the example configs and the web portal's editable-field promise. It is materially smaller than P06 itself and obviously paired with it. Could be folded into P06 before opening the PR (cleaner — one patch ships read AND write) or sent as a P06 follow-up.

If shipped as a follow-up, file it as Issue + PR after P06 has been merged (or at the same time as a chained PR).

## Discovery context

Discovered during the 2026-05-12 temperature-0.2 determinism experiment when Code attempted to set `"temperature": "0.2"` on a running chip and found all four mechanisms code-level-blocked. The experiment proceeded via Option A (change the C++ default in `configDefaults()`) as a one-line build-and-reflash workaround, but Option A is not deployable for end users — they need the write-side path.

See [sync/from_code.md](../../../sync/from_code.md) (2026-05-12 temperature-0.2 blocked-mechanisms handback) and [sync/worklog.md](../../../sync/worklog.md) for the discovery sequence.
