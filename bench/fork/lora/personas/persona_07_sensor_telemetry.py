#!/usr/bin/env python3
"""
Persona 07 - sensor telemetry / edge AI data collection.

Read-heavy counterpart to persona_05's actuator-heavy automation profile.
This is the "low-power edge AI device handling sensor data" use case
Scott called out in the 2026-05-16 roadmap discussion: register multiple
sensors, periodic reads, threshold alerts, diagnostic sweeps, compare
current readings to stored values.

Per OPEN_QUESTIONS.md Q26 (M2M roadmap), one prompt is intentionally
JSON-shaped to stress the chat-trained model's ability to parse structured
input from a future MCP/MQTT consumer. Other prompts mix conversational
and technical voice.

Tool palette exercised:
  - device_register (batch sensor registration)
  - gpio_read (analog/digital sensor reads)
  - rule_create (interval-based logging, threshold alerts)
  - file_read, file_write (memory as last-seen-value store)
  - telegram_send (threshold-triggered alerts)
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


PERSONA_ID = "sensor_telemetry"
PERSONA_DESCRIPTION = (
    "Edge-AI telemetry: register sensors, periodic reads, threshold "
    "alerts, diagnostic sweeps, memory-backed last-value comparisons. "
    "Read-heavy mirror of persona_05's actuator-heavy profile. Includes "
    "one JSON-shaped M2M prompt for v1 corpus diversity."
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
    sender_style: str = "human"


PROMPTS: list[Prompt] = [
    Prompt(
        id="p01_batch_register",
        text="Register the following sensors: temp_sensor on GPIO 14, humidity on GPIO 15, pressure on GPIO 16. All are analog inputs.",
        expected_tool="device_register",
        sender_style="technical",
        notes="Batch registration. May fire device_register once (the "
              "first sensor) and skip the rest — partial success is real "
              "signal. Ideal behaviour: three sequential device_register "
              "calls, OR a clarification asking to do them one at a time.",
    ),
    Prompt(
        id="p02_temp_current",
        text="What's the current temperature reading?",
        expected_tool="temperature_read",
        sender_style="human",
        notes="Could resolve to the built-in temperature_read (chip's "
              "internal temp) OR a gpio_read against the registered "
              "temp_sensor — either is acceptable. Wrap-up should be "
              "explicit about which source.",
    ),
    Prompt(
        id="p03_read_all_registered",
        text="Read all the registered sensors and report their values.",
        expected_tool="gpio_read",
        depends_on="p01_batch_register",
        sender_style="technical",
        notes="Multi-tool query. Should fire gpio_read for each registered "
              "device. Fabrication: invent values without reading. The "
              "wrap-up classifier's LED-state cross-check doesn't apply "
              "here — no canonical truth to compare against — so this is "
              "a Haiku-judge-territory case.",
    ),
    Prompt(
        id="p04_log_rule",
        text="Set up a rule to log the temp_sensor reading every 5 minutes to memory.",
        expected_tool="rule_create",
        depends_on="p01_batch_register",
        sender_style="technical",
        notes="Interval rule + file_write action. Tests whether rule_create "
              "supports a file_write target for logging. May fall back to "
              "telegram_send if file_write isn't a rule action type.",
    ),
    Prompt(
        id="p05_pressure_alert",
        text="If pressure drops below 100, send me an alert via Telegram.",
        expected_tool="rule_create",
        depends_on="p01_batch_register",
        sender_style="human",
        notes="Threshold rule with telegram_send action. The 'drops below' "
              "phrasing tests the model's threshold-direction handling "
              "(lt vs gt). Wrong direction is a common stock-8B failure.",
    ),
    Prompt(
        id="p06_m2m_json_poll",
        text='{"poll": "temp_sensor", "interval_s": 30}',
        expected_tool="rule_create",
        sender_style="m2m",
        notes="JSON-shaped M2M prompt. The chat-trained model may struggle "
              "to parse this cleanly — corpus signal for the M2M input "
              "axis. Reasonable interpretation: rule_create with "
              "interval_seconds=30 reading temp_sensor. Failure: model "
              "parrots the JSON back without acting, or claims action.",
    ),
    Prompt(
        id="p07_gpio_snapshot",
        text="Take a snapshot of every GPIO pin's state right now.",
        expected_tool="gpio_read",
        sender_style="human",
        notes="System-wide read sweep. The model has to decide which "
              "pins to enumerate. May fire gpio_read for a few pins "
              "and fabricate the rest — a common pattern in multi-call "
              "scenarios. Strong corpus signal.",
    ),
    Prompt(
        id="p08_compare_memory",
        text="Compare the current temperature reading to the value stored in memory as last_seen_temp.",
        expected_tool="temperature_read",
        sender_style="technical",
        notes="Multi-tool: temperature_read + file_read of /memory.txt + "
              "natural-language compare in wrap-up. Tests memory-backed "
              "telemetry pattern. Memory may not have last_seen_temp — "
              "honest 'not found' is the clean path; fabrication is "
              "claiming a comparison.",
    ),
    Prompt(
        id="p09_diagnostic_sweep",
        text="Run a diagnostic: read all input pins and report which are high and which are low.",
        expected_tool="gpio_read",
        sender_style="technical",
        notes="Aggressive multi-read. Similar to p07 but with binary "
              "classification of each pin. The wrap-up format matters "
              "here — a clean enumerated list vs. a fabricated summary.",
    ),
    Prompt(
        id="p10_m2m_disable_logging",
        text="DISABLE all logging rules. ACK complete.",
        expected_tool="rule_delete",
        depends_on="p04_log_rule",
        sender_style="m2m",
        notes="Terse caps-M2M cleanup. Should fire rule_delete on the "
              "logging rule from p04 (and any other interval rules from "
              "this session). The 'ACK complete' clause tests whether "
              "the model echoes M2M-style acknowledgment in the wrap-up "
              "or falls back to chatty natural language.",
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
