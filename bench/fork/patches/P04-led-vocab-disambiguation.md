# P04: LED rule vocabulary disambiguation in system prompt

**Bucket:** Upstream PR candidate
**Impact:** Medium — recovers T02 ("Turn off the LED") on 3 of 5 tested models
**Risk:** Very low — pure prompt rewrite, no code change
**Affected files:** `data/system_prompt.txt`

## Problem

The current "LED rules" paragraph in `data/system_prompt.txt` reads:

> LED rules:
> - The onboard LED is NOT a registered actuator. Do NOT use actuator_name for the LED.
> - For LED rules, use: on_action="led_set" with on_r, on_g, on_b (0-255) and off_action="led_set" with off_r, off_g, off_b.

The intended audience for that paragraph is `rule_create` calls (where you set `on_action="led_set"` with `on_r/on_g/on_b` *as rule parameters*). But the same paragraph appears in the prompt that introduces both the `led_set` tool (direct LED control, takes `r/g/b`) AND `rule_create` (rule definition, takes `on_r/off_r/etc`).

When the user says "Turn **off** the LED", three of five tested 8B models (qwen3:8b, qwen3-nothinker:latest, specialagentpuddy:8b) pattern-match the word **off** to the `off_r/off_g/off_b` vocabulary they just read, and emit:

```json
{"name": "led_set", "arguments": "{\"off_r\":0,\"off_g\":0,\"off_b\":0}"}
```

Which is a structurally invalid `led_set` call — the schema requires `r`, `g`, `b`, not `off_r`, `off_g`, `off_b`. The firmware tool dispatcher silently ignores the unknown args, and the LED stays in whatever state it was in.

## Solution

Rewrite the LED rules paragraph to clearly separate the two tools' vocabularies. Add a concrete `led_set` example for "off." This is also a small step toward fork patch P03 (example-augmented tools) but applied directly in the prompt instead of in the tool descriptions.

## Diff

### `data/system_prompt.txt`

Replace the existing 3-line "LED rules:" paragraph with:

```diff
-LED rules:
-- The onboard LED is NOT a registered actuator. Do NOT use actuator_name for the LED.
-- For LED rules, use: on_action="led_set" with on_r, on_g, on_b (0-255) and off_action="led_set" with off_r, off_g, off_b.
+LED control:
+- The onboard LED is NOT a registered actuator. Do NOT use actuator_name for the LED.
+- Direct LED control uses the `led_set` tool with parameters r, g, b (each 0-255).
+  Examples: "LED red" -> led_set(r=255, g=0, b=0). "LED off" -> led_set(r=0, g=0, b=0).
+- In `rule_create`, when on_action="led_set" the rule parameters are on_r/on_g/on_b
+  (and optionally off_r/off_g/off_b for the off action). These are DIFFERENT from
+  the led_set tool's r/g/b parameters -- on_r/off_r live on rule_create, NOT on led_set.
+- Rule example: "LED red when temp > 30, off when below" -> rule_create(sensor_name="chip_temp",
+  condition="gt", threshold=30, on_action="led_set", on_r=255, on_g=0, on_b=0,
+  off_action="led_set", off_r=0, off_g=0, off_b=0).
```

The new paragraph is ~3x longer (about 700 chars vs 250) but every line earns its place:

- Lines 1-2: scope (direct vs rule), tool name, parameter names.
- Lines 3-4: worked examples for direct control (covers T01 LED-red and T02 LED-off).
- Lines 5-6: explicit collision callout — `on_r` lives on `rule_create`, not `led_set`.
- Lines 7-9: worked example for the rule case (which is what the original paragraph was trying to teach).

## Test plan

After applying this and P02 (truncation fix, so the longer paragraph still fits in the buffer):

1. Rerun bench with same baselines. T02 should flip to PASS on qwen3:8b, qwen3-nothinker, specialagentpuddy.
2. T01 and T14 (LED-red direct, LED-red rule) should remain PASS — no regression.
3. T13 (LED-green direct) should remain PASS.

## Upstream PR text

```
Title: Disambiguate led_set vs rule_create parameter names in system prompt

Background:
Three of five 8B models in our tool-calling bench fail "Turn off the LED"
by emitting led_set with off_r/off_g/off_b instead of r/g/b. The reason is
the LED rules paragraph in system_prompt.txt teaches "off_r/off_g/off_b"
in the context of LED control, without making clear that those parameter
names live on rule_create (the rule definition tool), not on led_set (the
direct control tool).

Models pattern-match the word "off" in the user request to the off_*
vocabulary they just read, and emit a structurally invalid led_set call.
The firmware dispatcher silently ignores the unknown args and the LED
state doesn't change.

Change:
Rewrite the LED rules paragraph to:
- Split the two tools' parameter vocabularies explicitly.
- Add worked examples for both "LED red" (direct) and "LED off" (direct).
- Add a worked example for the rule case.
- Add an explicit "DIFFERENT from led_set's r/g/b" callout to break the
  word-matching pattern.

Bench data: T02 ("Turn off the LED") flips to PASS on qwen3:8b,
qwen3-nothinker, and specialagentpuddy with this change. No regression on
T01 (LED red direct), T13 (LED green direct), or T14 (LED-red rule).

(Depends on P02 to fit in the system prompt buffer, or shrink other
sections.)
```
