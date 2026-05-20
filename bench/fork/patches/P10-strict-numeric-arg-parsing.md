# P10: Strict numeric arg parsing in tool dispatcher

**Bucket:** Upstream PR candidate
**Impact:** Medium — silent integer-coercion of JSON-string args produces semantically broken rules with no operator-visible error
**Risk:** Low — replaces silent coercion with either a strict reject or a stricter parse; either way, the bug becomes visible
**Affected files:** `src/tools.cpp` (multiple atoi/jsonArgString call sites)
**Status:** Drafted, not implemented. Filed because the bug was observed empirically and shouldn't be lost.

## Problem

WireClaw's tool argument parser silently coerces JSON-string values to integers via `atoi()`. When the model emits an integer argument as a string (e.g., `"threshold":"30"` instead of `"threshold":30`), the chip's parser:

1. Pulls the value out as a string (via `jsonArgString`).
2. Passes it to `atoi()`.
3. `atoi()` of a non-numeric leading character returns 0 silently with no error indication.

In the specific case of `"threshold":"30"` from a model that wraps numbers as strings, the chip parses threshold as `0`, NOT `30`. Rules built on this get the wrong threshold — typically becoming "always-true" predicates (`chip_temp > 0` is always true).

### Empirical evidence (2026-05-12 step 5 probe A)

User prompt: "When the chip temperature goes above 30 degrees Celsius, send me a Telegram alert and turn the LED red 5 seconds later."

Model emitted (captured in serial log):

```
rule_create({
  "interval_seconds":"0",
  "off_action":"led_set",
  "off_b":"0",
  "rule_name":"chip_temp_alert",
  "condition":"gt",
  "on_action":"telegram",
  "off_r":"255",
  "off_g":"0",
  "chain_delay_seconds":"5",
  "threshold":"30",
  "sensor_name":"chip_temp",
  "on_telegram_message":"Chip: {value}C"
})
```

Every numeric arg is a JSON string (`"0"`, `"5"`, `"30"`, `"255"`). The chip
parsed `threshold:"30"` as `0` and saved a rule with effective semantics
`chip_temp > 0 (every 5s) with auto-off`. Since chip_temp is always > 0,
the rule fired immediately and continuously, sending Scott a "Chip: 28C"
Telegram alert as soon as it was created — and would have continued every
5 seconds until manually deleted.

This was logged on chip as:

```
Rule created: rule_01 'chip_temp_alert' - chip_temp > 0 (every 5s) with auto-off
```

Note the threshold of `0` in the chip's own rule summary. The chip *knew*
the threshold ended up at 0 and reported it back, but the operator-visible
error was zero — the rule appeared to save successfully.

## Code site (no fix in this patch — citation only)

Search `src/tools.cpp` for `atoi(` to find affected call sites. Each one
that backs an integer-typed schema field is potentially affected. As of
the WireClaw-fork tree on `bisect-step5-P02redesign-P01v2`, the relevant
calls are in the rule_create / chain_create / device_register handlers
where numeric fields like threshold, interval_seconds, on_r/on_g/on_b,
pin, etc. are extracted via `jsonArgString` then `atoi`-coerced.

## Solution sketch (not implemented in this patch)

Two acceptable approaches:

### Approach A: strict parse with error on non-numeric

Replace `atoi(strval)` with `strtol(strval, &endptr, 10)` and check
`*endptr == '\0'`. If the string isn't a clean integer, return an error
message ("expected integer for `threshold`, got string `30abc`") rather
than silently coercing to 0.

This is the most defensive and would have caught the empirical case
above — the model's `"30"` is a clean integer string and would parse
correctly under `strtol` with endptr check (no behavior change for valid
strings; only catches the silent-coercion bug for `atoi("hello") -> 0`-
style errors).

But it does NOT catch the original failure mode here: the model sent
`"30"` (a valid string-of-integer), and `atoi("30")` correctly returns
30 — the threshold being parsed as 0 must be elsewhere in the call
chain. **Need to re-investigate before implementing**: the actual root
cause might be a JSON-parser issue downstream, not the atoi step. Worth
running a quick test: feed the captured args verbatim through the chip
and trace where 30 becomes 0.

### Approach B: schema-aware reject of string-typed integer args

Add a `jsonArgInt()` helper that pulls a JSON value as a true integer
(rejecting JSON strings even if they parse as integers) and use it for
all integer-typed fields. This forces the model to emit `"threshold":30`
(bare number) rather than `"threshold":"30"` (string). More strict;
might reduce false-positive arg coercions in pathological model outputs.

But this is more invasive (requires a JSON-aware integer extractor that
handles whitespace, commas, etc.) and might over-reject in edge cases.

### Recommendation

Investigate first to confirm the root cause. The captured evidence shows
`"threshold":"30"` from the model and `chip_temp > 0` in the chip's rule
summary — between those two points, *something* maps "30" to 0. If it's
`atoi("30") -> 30` followed by a downstream zero-out, the fix is somewhere
in rule_create's serialization. If it's an upstream JSON-parser issue
that strips quotes wrong, the fix is there. If it's `jsonArgString` returning
empty (and atoi("") returns 0), the fix is in the JSON helper.

Don't pick an approach until the trace is clear.

## Test plan

Once implemented:

1. Reproduce empirically: send the probe-A prompt verbatim, confirm the
   buggy rule_01 used to be created. (Pre-fix snapshot.)
2. With fix: same prompt, confirm either (a) rule_create returns error
   (approach B), (b) rule_create returns success with threshold = 30
   correctly (if the root cause was non-atoi-related), or (c) rule_create
   returns error citing the wrong arg type (approach A on a different
   string-coercion path).
3. Regression: run the existing bench against a fixed firmware. Expect
   no new failures on tests that use string vs integer args correctly.

## Upstream-ability

Likely yes. Silent integer coercion is a generic firmware bug, not
WhitneyDesignLabs-specific. Could ship as a small follow-up to the
existing tool dispatcher, after the root-cause investigation above.

## Discovery context

Discovered during 2026-05-12 step 5 probe A. The buggy rule_01 fired
immediately and continuously on the chip, producing spurious Telegram
alerts; Scott noticed and we deleted it manually. Without the empirical
catch, this bug would silently corrupt any rule built from a string-
typed-integer model output.

See [sync/from_code.md](../../../sync/from_code.md) (step 5 handback,
2026-05-12) for the full failure capture.

## Related patches

- **P01 / P01-v2** — leak detector that catches Mode-A prose leaks.
  Distinct concern (parser correctness for valid-looking tool calls vs.
  detecting structurally-invalid prose-leaked tool calls). Both
  contribute to the "chip surfaces real errors instead of silently
  saving broken state" theme.
- **P08** (config write-side completeness), **P09** (file_write/read
  buffer caps) — same family of "operator-visible behavior matches
  operator intent" patches.
