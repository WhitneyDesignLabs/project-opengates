#!/usr/bin/env python3
"""
Persona 05 - automation operator (home / shop automation).

This is the FIRST of three personas weighted toward Scott's actual
deployment domain: automation, robotics, CNC, security, edge sensor data.
Where personas 01-04 leaned conversational/LED/memory, 05-07 lean
GPIO/actuator/sensor/rule with realistic relay control, scheduled actions,
and sensor-triggered automation.

Per Scott's 2026-05-16 roadmap note: production deployments will likely
have non-human prompt sources (upstream AI orchestrators, MQTT brokers,
MCP servers). The prompts here intentionally mix sender styles to seed
the v1 corpus with that diversity:

  - Conversational: human-typed Telegram-style.
  - Technical / mid-level: automation-system voice (verb + parameters).
  - Terse M2M: command-line-ish or key=value, as an upstream orchestrator
    might send through a future MQTT/MCP bridge.

The mix lets the v1 LoRA see what real-world input distribution looks like
before the bridge architecture is built.

Tool palette exercised (best-guess; the model's actual picks will inform
ground truth):
  - actuator_set, gpio_set, gpio_read
  - device_register (relay, motion sensor, door sensor)
  - rule_create (threshold + interval), chain_create (motion -> light)
  - rule_list, rule_delete
  - telegram_send (alert action)
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


PERSONA_ID = "automation_operator"
PERSONA_DESCRIPTION = (
    "Home / shop automation: relays, scheduled actions, sensor-triggered "
    "rules. Mixed sender style (human Telegram, automation-system voice, "
    "terse M2M command-line) to represent the production input "
    "distribution."
)

INTERACTION_DELAY_S = 6.0
CLEAR_HISTORY_BETWEEN_RUNS = True


@dataclass(frozen=True)
class Prompt:
    id: str
    text: str
    expected_tool: str | None
    notes: str = ""
    depends_on: str | None = None
    sender_style: str = "human"  # "human" | "technical" | "m2m"


PROMPTS: list[Prompt] = [
    Prompt(
        id="p01_relay_lights",
        text="Turn on the workshop lights via the relay on GPIO 5.",
        expected_tool="gpio_set",
        sender_style="human",
        notes="Direct GPIO control via human phrasing. May resolve to gpio_set "
              "or actuator_set depending on the model's preference. Either is "
              "acceptable if the right pin (5) and state (high) come through.",
    ),
    Prompt(
        id="p02_device_register_pump",
        text="Register a new actuator: name water_pump, GPIO 22, type relay.",
        expected_tool="device_register",
        sender_style="technical",
        notes="Automation-system voice. Tests device_register's full arg "
              "shape (name, gpio, type). Watch for the model fabricating "
              "success without firing the tool, or stripping args.",
    ),
    Prompt(
        id="p03_humidity_rule",
        text="Set up a rule: when humidity reads above 70, run the dehumidifier for 15 minutes.",
        expected_tool="rule_create",
        sender_style="human",
        notes="Threshold rule + bounded-duration action. WireClaw's rule_create "
              "may or may not support bounded durations cleanly — partial "
              "success is real signal here.",
    ),
    Prompt(
        id="p04_door_state",
        text="Read the door sensor on GPIO 4 and let me know if it's open or closed.",
        expected_tool="gpio_read",
        sender_style="human",
        notes="Sensor read + state interpretation. Wrap-up should report "
              "the pin state truthfully (high or low). Fabrication: invent "
              "open/closed without reading the pin.",
    ),
    Prompt(
        id="p05_schedule_heater",
        text="Schedule the heater to turn off at 22:00 daily.",
        expected_tool="rule_create",
        sender_style="technical",
        notes="Time-based rule (the bake's T12-class case). Repeating daily. "
              "Tests clock_hhmm condition + scheduled action.",
    ),
    Prompt(
        id="p06_m2m_pump_command",
        text="execute: water_pump on duration=30s",
        expected_tool="actuator_set",
        depends_on="p02_device_register_pump",
        sender_style="m2m",
        notes="Terse M2M command-style. Tests whether the chat-trained model "
              "can parse compact verb-target-args. Expected: actuator_set "
              "with name=water_pump, state=on, OR rule_create for the "
              "30-second bound. Either is reasonable; fabrication risk is "
              "the model claiming the action without firing any tool.",
    ),
    Prompt(
        id="p07_motion_porch_chain",
        text="When motion is detected on GPIO 16, turn on the porch light for 5 minutes.",
        expected_tool="chain_create",
        sender_style="technical",
        notes="Sensor trigger + actuator action + duration. Tests chain_create "
              "(the project's historically-weak compound primitive) on a "
              "realistic automation pattern.",
    ),
    Prompt(
        id="p08_rule_list",
        text="Show me a list of all the automation rules running right now.",
        expected_tool="rule_list",
        sender_style="human",
        notes="Self-query. Wrap-up should enumerate rule names + their "
              "actions. Fabrication: invent rules that don't exist, or "
              "claim 'no rules' when several were just created above.",
    ),
    Prompt(
        id="p09_rule_delete_named",
        text="Cancel the porch light motion rule.",
        expected_tool="rule_delete",
        depends_on="p07_motion_porch_chain",
        sender_style="human",
        notes="Targeted cleanup by description (not by exact rule_name). "
              "Tests the model's ability to resolve a human reference "
              "('the porch light motion rule') to a stored rule's "
              "rule_name. Often partial-fails on stock 8B.",
    ),
    Prompt(
        id="p10_m2m_relay_off",
        text="set relay name=water_pump state=off",
        expected_tool="actuator_set",
        depends_on="p02_device_register_pump",
        sender_style="m2m",
        notes="Terse M2M key=value command. Tests parameter parsing under "
              "M2M-style input. Should resolve to actuator_set with "
              "name=water_pump, state=off. End-of-session cleanup that "
              "also stress-tests the M2M input shape.",
    ),
]


def battery_summary() -> str:
    sender_mix = {}
    for p in PROMPTS:
        sender_mix[p.sender_style] = sender_mix.get(p.sender_style, 0) + 1
    return (
        f"persona={PERSONA_ID} prompts={len(PROMPTS)} "
        f"sender_mix={sender_mix} "
        f"tools_exercised={sorted({p.expected_tool for p in PROMPTS if p.expected_tool})}"
    )


def to_dict() -> dict[str, Any]:
    return {
        "persona_id": PERSONA_ID,
        "description": PERSONA_DESCRIPTION,
        "interaction_delay_s": INTERACTION_DELAY_S,
        "clear_history_between_runs": CLEAR_HISTORY_BETWEEN_RUNS,
        "prompts": [
            {"id": p.id, "text": p.text, "expected_tool": p.expected_tool,
             "depends_on": p.depends_on, "sender_style": p.sender_style,
             "notes": p.notes}
            for p in PROMPTS
        ],
    }


if __name__ == "__main__":
    import json
    print(battery_summary())
    print()
    print(json.dumps(to_dict(), indent=2))
