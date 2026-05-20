#!/usr/bin/env python3
"""
Persona 01 - basic operator (pilot persona).

The first persona for the WireClaw Phase 3.1 capture-fleet. Defines a 10-prompt
smoke battery that exercises the breadth of the WireClaw tool palette: chip read,
LED actuator (including the historically-failing LED-off vocab), memory recall,
memory write, the compound LED-favorite-color "project nemesis", a periodic rule,
a threshold rule, an info read, and an off-domain refusal.

The prompt list extends the four Phase 2B smoke conversations
(`bench/fork/lora/seed-corpus/phase2b-chipside-2026-05-13.json`) so the pilot's
captured corpus is comparable to that baseline.

## Driving the persona

**Single-pair pilot (now):** the prompts are DRIVEN MANUALLY by Scott via Telegram,
one at a time, with `/clear` between sessions if state needs resetting. The Pi's
role in the pilot is corpus capture, not user simulation. Watching the chip's
serial output on COM17 (Code) and the Telegram-side replies (Scott) gives the
two halves of each conversation.

**Phase 3.1 at-scale (future):** this module will be extended with a Telethon-based
userbot client (`TelethonDriver` class) that sends the prompts via Telegram on
behalf of a registered user account, paces them per `interaction_delay_s`, and
handles `/clear` between persona-runs. The prompt list itself does not change
between pilot and scale-up.

## Memory state assumption

The chip's `/memory.txt` is expected to be in a known state before this persona
runs. Default assumption: `/memory.txt` = "favorite color is purple" (matches the
Phase 2B baseline and `seed-corpus/phase2b-chipside-2026-05-13.json`). Prompt 9
deliberately writes a new value ("blue") and prompt 10 reads it back -- if the
chip's memory is in a different state going in, swap the colors but keep the
write-then-read pattern intact.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


PERSONA_ID = "basic_operator"
PERSONA_DESCRIPTION = (
    "A non-technical operator using the chip for common WireClaw tasks: "
    "checking sensor state, controlling the LED, saving/recalling preferences, "
    "setting up automation rules."
)

# Pacing for at-scale operation. Pilot is manual; this is advisory for Phase 3.1.
INTERACTION_DELAY_S = 6.0
CLEAR_HISTORY_BETWEEN_RUNS = True


@dataclass(frozen=True)
class Prompt:
    """One smoke-battery prompt with grading hints for Code's pilot pass/fail check."""

    id: str
    text: str
    expected_tool: str | None       # primary tool the chip should call (None = off-domain)
    notes: str = ""
    # If the prompt sequence later depends on state set by an earlier prompt,
    # name it here so Code can sanity-check ordering.
    depends_on: str | None = None


# Memory-state assumption at session start: /memory.txt = "favorite color is purple".
PROMPTS: list[Prompt] = [
    Prompt(
        id="p01_chip_temp",
        text="What is the chip temperature?",
        expected_tool="temperature_read",
        notes="Direct chip read. Mirrors Phase 2B smoke-1. Watch for pseudo-prose "
              "wrap-up ('(I called the temperature_read tool and it returned X.)') -- "
              "expected residual failure mode of wireclaw-agent:v1, not a blocker.",
    ),
    Prompt(
        id="p02_led_red",
        text="Set the LED to red.",
        expected_tool="led_set",
        notes="Simple actuator, single-tool. Mirrors Phase 2B smoke-3. LED must "
              "visibly go red.",
    ),
    Prompt(
        id="p03_memory_recall",
        text="What is my favorite color?",
        expected_tool="file_read",
        notes="Memory recall. Chip should file_read('/memory.txt'). Watch for the "
              "wrap-up to report 'purple' without fabricating an LED state change "
              "(the Phase 2B smoke-2 fabrication mode).",
    ),
    Prompt(
        id="p04_compound_favorite_color",
        text="Set the LED to my favorite color.",
        expected_tool="led_set",
        depends_on="p03_memory_recall",
        notes="The project NEMESIS (Phase 2B smoke-4). Expects file_read + led_set "
              "in one turn, with the wrap-up matching the actual LED state. Known "
              "to fail intermittently due to tool-name collision under multi-tool "
              "context -- LoRA target. Track outcome verbatim either way.",
    ),
    Prompt(
        id="p05_led_off",
        text="Set the LED off.",
        expected_tool="led_set",
        notes="LED-off via led_set({r:0,g:0,b:0}). Historically failed on stock 8B "
              "models due to off_r/off_g/off_b (rule_create) vocabulary collision; "
              "P04-redesign was meant to fix that. Confirms wdl-v1's prompt does too.",
    ),
    Prompt(
        id="p06_info_ip",
        text="What is your IP address?",
        expected_tool="device_info",
        notes="Self-info read. Should NOT fabricate; should return the chip's "
              "actual STA IP.",
    ),
    Prompt(
        id="p07_periodic_rule",
        text="Remind me every 5 minutes to check the heater.",
        expected_tool="rule_create",
        notes="Periodic rule with telegram action. Probe B from prior sessions. "
              "Expected args include condition='always', interval_seconds=300, "
              "action with telegram message.",
    ),
    Prompt(
        id="p08_threshold_rule",
        text="When the chip temperature is above 30 degrees, send me a Telegram alert.",
        expected_tool="rule_create",
        notes="Threshold rule. Expected args include condition='gt' (or similar), "
              "threshold=30, with chip_temperature source.",
    ),
    Prompt(
        id="p09_memory_write",
        text="My new favorite color is blue.",
        expected_tool="file_write",
        notes="Memory write. Overwrites /memory.txt with the new color. Watch for "
              "pseudo-prose like '(file_write(path=...))' wrap-up.",
    ),
    Prompt(
        id="p10_compound_after_write",
        text="Set the LED to my favorite color.",
        expected_tool="led_set",
        depends_on="p09_memory_write",
        notes="Compound after the p09 write. LED should now go BLUE, not purple. "
              "Tests whether the chip uses the updated memory state. If it goes "
              "purple, the history-replay path is overriding the fresh file_read.",
    ),
]


def battery_summary() -> str:
    """One-line text summary of the battery, useful for logging."""
    return (
        f"persona={PERSONA_ID} prompts={len(PROMPTS)} "
        f"tools_exercised={sorted({p.expected_tool for p in PROMPTS if p.expected_tool})}"
    )


def to_dict() -> dict[str, Any]:
    """Serialisable form for logging / corpus headers."""
    return {
        "persona_id": PERSONA_ID,
        "description": PERSONA_DESCRIPTION,
        "interaction_delay_s": INTERACTION_DELAY_S,
        "clear_history_between_runs": CLEAR_HISTORY_BETWEEN_RUNS,
        "prompts": [
            {"id": p.id, "text": p.text, "expected_tool": p.expected_tool,
             "depends_on": p.depends_on, "notes": p.notes}
            for p in PROMPTS
        ],
    }


if __name__ == "__main__":
    import json
    print(battery_summary())
    print()
    print(json.dumps(to_dict(), indent=2))
