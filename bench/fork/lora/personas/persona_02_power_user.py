#!/usr/bin/env python3
"""
Persona 02 - power user.

Counterpart to persona_01_basic (the non-technical operator). This one talks
to the chip like a developer who knows the tool palette: direct technical
language, occasional explicit tool references, deliberate exercise of
rule-engine lifecycle (create / list / delete), chain_create for multi-step
compounds, and multi-tool status queries.

Failure-mode targets:
  - chain_create has been a historical weak spot (Phase 1 finding pre-bake).
    Several prompts here exercise it directly.
  - Rule lifecycle (delete by rule_name, delete-all semantics) was never
    properly tested before the 3.1.1 overnight surfaced the rule-engine
    cap issue. This persona forces the chip to manage rule state across
    a session.
  - Multi-tool wrap-ups (one prompt that requires several tools to fire)
    historically produce more pseudo-prose and more tool-name collisions.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


PERSONA_ID = "power_user"
PERSONA_DESCRIPTION = (
    "A developer-savvy operator who knows the WireClaw tool palette: uses "
    "direct technical phrasing, names tools by intent, exercises rule "
    "lifecycle and chain_create, asks for multi-tool status reports."
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


# Memory-state assumption at session start: /memory.txt = "favorite color is purple".
# (Or whatever the chip happens to have — this persona doesn't heavily depend on it.)
PROMPTS: list[Prompt] = [
    Prompt(
        id="p01_rule_list",
        text="Show me the rules currently registered on the chip.",
        expected_tool="rule_list",
        notes="Direct tool-intent prompt. Model should pick rule_list. Wrap-up "
              "may legitimately be 'No rules' or the list contents — both are "
              "clean. Phrasing avoids the /rules bot command to force the LLM "
              "path, not the chip's slash-command path.",
    ),
    Prompt(
        id="p02_rule_create_named",
        text="Create a rule named 'temp_log' that sends me the current temperature every 10 minutes via Telegram.",
        expected_tool="rule_create",
        notes="Tests the rule_name required-argument (where stock 8B used to "
              "fabricate-success on missing rule_name). Also tests 10-minute "
              "interval_seconds = 600.",
    ),
    Prompt(
        id="p03_rule_delete_named",
        text="Delete the rule called 'temp_log'.",
        expected_tool="rule_delete",
        depends_on="p02_rule_create_named",
        notes="Tests rule_delete by name. If p02 failed to create the rule, "
              "this should produce a 'no such rule' result and a wrap-up "
              "that's honest about it (not a fabricated 'rule deleted').",
    ),
    Prompt(
        id="p04_chain_threshold_alert",
        text="When the chip temperature goes above 28 degrees, set the LED to orange and send me a Telegram alert.",
        expected_tool="chain_create",
        notes="The chain_create test the project's been needing. Compound "
              "trigger + dual action. May fall back to rule_create with a "
              "multi-action; either way it's strong corpus signal. Orange "
              "RGB = (255, 165, 0) per the bake's mapping.",
    ),
    Prompt(
        id="p05_chain_telegram_trigger",
        text="When I send the message 'panic' on Telegram, set the LED red and reply 'standing by'.",
        expected_tool="chain_create",
        notes="Tests chained Telegram trigger + dual action. Historically "
              "ambitious for 8B; expect a moderate failure rate (clarification "
              "or fabricated-success or rule_create-instead-of-chain).",
    ),
    Prompt(
        id="p06_memory_direct_read",
        text="Read /memory.txt and tell me exactly what's in it.",
        expected_tool="file_read",
        notes="Memory recall with direct path. Wrap-up should report verbatim "
              "content. Tests whether the model passes through the file_read "
              "result faithfully or paraphrases it (paraphrase = potential "
              "fabrication if content drifts).",
    ),
    Prompt(
        id="p07_multitool_status",
        text="Give me a status report: IP address, current chip temperature, free heap, and a count of active rules.",
        expected_tool="device_info",
        notes="Multi-tool query — needs device_info AND temperature_read AND "
              "rule_list. Historical weak point: model picks one tool and "
              "fabricates the rest. Strong corpus signal whether or not all "
              "three fire.",
    ),
    Prompt(
        id="p08_gpio_direct",
        text="Set GPIO pin 5 high.",
        expected_tool="actuator_set",
        notes="Direct hardware actuator. Tests gpio_set or actuator_set "
              "(palette-dependent). May fabricate if the chip's tool palette "
              "doesn't expose direct GPIO control on this firmware.",
    ),
    Prompt(
        id="p09_rule_threshold_led",
        text="Create a rule called 'temp_warning' that turns the LED yellow whenever the chip temperature exceeds 28 degrees.",
        expected_tool="rule_create",
        notes="Threshold rule with LED action (vs telegram action). Tests "
              "rule_create's action-type plumbing. Yellow RGB = (255, 255, 0).",
    ),
    Prompt(
        id="p10_rule_cleanup",
        text="Delete all rules you've created during this session.",
        expected_tool="rule_delete",
        depends_on="p09_rule_threshold_led",
        notes="Cleanup semantics test. Model needs to call rule_delete multiple "
              "times (or know an 'all' shorthand if the palette supports it). "
              "Likely to fabricate success on first call. This prompt is "
              "specifically why we need a rule-purge bookend in the wrapper — "
              "we can't rely on the LLM to clean up reliably.",
    ),
]


def battery_summary() -> str:
    return (
        f"persona={PERSONA_ID} prompts={len(PROMPTS)} "
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
             "depends_on": p.depends_on, "notes": p.notes}
            for p in PROMPTS
        ],
    }


if __name__ == "__main__":
    import json
    print(battery_summary())
    print()
    print(json.dumps(to_dict(), indent=2))
