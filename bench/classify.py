"""
Failure-mode classifiers for the WireClaw tool-calling bench.

Implements detectors for the failure modes documented in Scott's primer
(Project Opengates context, May 2026):

  Mode A: Text leak. Tool intent emitted as prose/markdown in `content`
          instead of populating `tool_calls`. The most dangerous mode for
          headless wire protocols -- WireClaw's parser silently drops these.
  Mode B: Argument abbreviation. Tool name correct, structurally valid call,
          but string arg truncated (e.g. 'home.temp' instead of 'home.kitchen.temperature').
  Mode C: Wrong tool format protocol. Model emits <tool_call>...</tool_call>
          XML or other framework-specific format instead of OpenAI tool_calls JSON.
          This is a sub-type of Mode A from the parser's perspective but warrants
          separate classification because the fix is different (parser support
          for XML vs. retry prompt for prose).
  Mode D: Context drowning / refusal / off-task. Model produces coherent prose
          but does not act -- "I would set the LED to red" rather than calling
          led_set. Hard to detect heuristically. We flag responses that have no
          tool_calls AND no Mode-A/C leak markers AND a non-trivial content body.
  Mode E: Streaming chunk loss. Not classified here; tested separately via a
          dedicated streaming probe in run.py.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Any


# ----------------------------------------------------------------------------
# Leak detectors
# ----------------------------------------------------------------------------

# XML tool-call formats used by various open-weight models.
# Qwen, Hermes, and several function-calling fine-tunes emit these.
_XML_LEAK_PATTERNS = [
    re.compile(r"<tool_call>", re.IGNORECASE),
    re.compile(r"</tool_call>", re.IGNORECASE),
    re.compile(r"<function_calls?>", re.IGNORECASE),
    re.compile(r"<invoke\b", re.IGNORECASE),
    re.compile(r"<parameter\b", re.IGNORECASE),
    re.compile(r"<tools?_use>", re.IGNORECASE),
]

# Fenced JSON code blocks that contain something call-shaped.
_FENCED_JSON_PATTERN = re.compile(
    r"```(?:json)?\s*\{[^`]*?(?:\"name\"|\"function\"|\"tool\"|\"arguments\")[^`]*?\}\s*```",
    re.DOTALL,
)

# Inline call syntax: known tool name followed by parenthesized args.
# Loaded with tool names at runtime.
_inline_call_pattern: re.Pattern | None = None


def init_tool_names(tool_names: list[str]) -> None:
    """Build a regex matching `<tool_name>(...)` for any known tool."""
    global _inline_call_pattern
    if not tool_names:
        _inline_call_pattern = None
        return
    escaped = "|".join(re.escape(n) for n in tool_names)
    _inline_call_pattern = re.compile(
        rf"\b({escaped})\s*\(", re.IGNORECASE
    )


def detect_xml_leak(content: str) -> str | None:
    """Return the first XML leak marker found, or None."""
    if not content:
        return None
    for pat in _XML_LEAK_PATTERNS:
        m = pat.search(content)
        if m:
            return m.group(0)
    return None


def detect_fenced_json_leak(content: str) -> str | None:
    """Return the first fenced-JSON tool-call block found, or None."""
    if not content:
        return None
    m = _FENCED_JSON_PATTERN.search(content)
    return m.group(0)[:120] if m else None


def detect_inline_call_leak(content: str) -> str | None:
    """Return the first `tool_name(...)` inline call found, or None."""
    if not content or _inline_call_pattern is None:
        return None
    m = _inline_call_pattern.search(content)
    return m.group(0) if m else None


def classify_no_tool_response(content: str) -> tuple[str, str]:
    """
    For a response with no tool_calls field, decide between Mode A, C, D.

    Returns (mode, evidence) where mode is one of:
      'C' -- XML leak (specific sub-type)
      'A' -- prose-style leak (fenced JSON or inline call syntax)
      'D' -- no actionable signal found; model just chatted
    """
    xml = detect_xml_leak(content)
    if xml:
        return ("C", f"XML marker: {xml!r}")

    fenced = detect_fenced_json_leak(content)
    if fenced:
        return ("A", f"Fenced JSON block: {fenced!r}")

    inline = detect_inline_call_leak(content)
    if inline:
        return ("A", f"Inline call syntax: {inline!r}")

    return ("D", f"No tool_calls, no leak markers, content len={len(content or '')}")


# ----------------------------------------------------------------------------
# Argument checkers
# ----------------------------------------------------------------------------

def _coerce_int(v: Any) -> int | None:
    """Best-effort integer coercion. Models sometimes emit numbers as strings."""
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, int):
        return v
    if isinstance(v, float):
        if v.is_integer():
            return int(v)
        return None
    if isinstance(v, str):
        try:
            return int(v)
        except ValueError:
            try:
                f = float(v)
                if f.is_integer():
                    return int(f)
            except ValueError:
                pass
    return None


def check_arg(actual: Any, checker: dict) -> tuple[bool, str]:
    """
    Apply a checker spec to an actual value. Returns (ok, explanation).
    Checker spec is a dict with exactly one of:
      exact          -- equality (with int/str coercion tolerance)
      contains       -- substring (case-insensitive)
      contains_all   -- list of substrings, all must be present (case-insensitive)
      contains_any   -- list of substrings, at least one must be present
      regex          -- regex match
      one_of         -- value in a list
      integer_range  -- [min, max] inclusive
      present        -- value just needs to exist (truthy or not)
    """
    if actual is None and "present" not in checker:
        return False, f"arg missing (got None)"

    if "exact" in checker:
        expected = checker["exact"]
        if isinstance(expected, int):
            a = _coerce_int(actual)
            if a is None:
                return False, f"expected int {expected!r}, got {actual!r}"
            return (a == expected, f"exact: expected {expected!r}, got {a!r}")
        # String/other: case-sensitive equality, but tolerate int<->str coercion
        return (
            str(actual) == str(expected),
            f"exact: expected {expected!r}, got {actual!r}",
        )

    if "contains" in checker:
        needle = str(checker["contains"]).lower()
        hay = str(actual).lower()
        return (needle in hay, f"contains {needle!r}? hay={hay[:80]!r}")

    if "contains_all" in checker:
        needles = [str(n).lower() for n in checker["contains_all"]]
        hay = str(actual).lower()
        missing = [n for n in needles if n not in hay]
        return (
            not missing,
            f"contains_all: missing {missing!r}" if missing else "all present",
        )

    if "contains_any" in checker:
        needles = [str(n).lower() for n in checker["contains_any"]]
        hay = str(actual).lower()
        hits = [n for n in needles if n in hay]
        return (
            bool(hits),
            f"contains_any: hits={hits!r}" if hits else f"none of {needles!r}",
        )

    if "regex" in checker:
        pat = re.compile(checker["regex"])
        m = pat.search(str(actual))
        return (m is not None, f"regex {checker['regex']!r}: {'match' if m else 'no match'}")

    if "one_of" in checker:
        options = checker["one_of"]
        return (
            actual in options or str(actual) in [str(o) for o in options],
            f"one_of {options!r}: got {actual!r}",
        )

    if "integer_range" in checker:
        lo, hi = checker["integer_range"]
        a = _coerce_int(actual)
        if a is None:
            return False, f"expected int in [{lo},{hi}], got {actual!r}"
        return (lo <= a <= hi, f"integer_range [{lo},{hi}]: got {a}")

    if "present" in checker:
        ok = actual is not None
        return (ok, f"present: {'yes' if ok else 'no'}")

    return False, f"unknown checker shape: {checker!r}"


# ----------------------------------------------------------------------------
# Test-case classifier (orchestrates the above)
# ----------------------------------------------------------------------------

@dataclass
class CaseResult:
    case_id: str
    passed: bool
    failure_mode: str  # 'A' | 'B' | 'C' | 'D' | 'WRONG_TOOL' | 'WRONG_ARGS' | 'FORBIDDEN_TOOL' | 'API_ERROR' | 'none'
    details: list[str] = field(default_factory=list)
    tool_calls_observed: list[dict] = field(default_factory=list)
    content_observed: str = ""
    latency_ms: int = 0
    raw_response: dict = field(default_factory=dict)


def classify_case(
    case: dict,
    response_message: dict,
    api_error: str | None = None,
) -> CaseResult:
    """
    Given a test case spec and an OpenAI-format response `message` dict,
    decide whether it passes and (if not) which failure mode it exhibits.

    response_message is the message object inside choices[0].message of the
    chat-completions response: { "role": "assistant", "content": ..., "tool_calls": [...] }
    """
    res = CaseResult(
        case_id=case["id"],
        passed=False,
        failure_mode="none",
    )

    if api_error:
        res.failure_mode = "API_ERROR"
        res.details.append(f"API error: {api_error}")
        return res

    tool_calls = response_message.get("tool_calls") or []
    content = response_message.get("content") or ""
    res.tool_calls_observed = tool_calls
    res.content_observed = content

    expected_tools = case.get("expected_tools", []) or []
    forbidden_tools = case.get("forbidden_tools", []) or []
    expected_args = case.get("expected_args", {}) or {}

    # ---- Negative case: expected NO tool calls ----------------------------
    if not expected_tools:
        # Off-domain test: model should answer conversationally.
        if tool_calls:
            called = [tc.get("function", {}).get("name") for tc in tool_calls]
            forbidden_hit = [n for n in called if n in forbidden_tools]
            if forbidden_hit:
                res.failure_mode = "FORBIDDEN_TOOL"
                res.details.append(f"Called forbidden tool(s): {forbidden_hit}")
                return res
            # Called some tool but none forbidden -- still arguably wrong for
            # an off-domain query, but be permissive.
            res.details.append(f"Negative case: model called tool(s) {called}; not forbidden but unusual")
            res.passed = True
            return res
        # No tool calls and no expectation -- this is the pass path for off-domain.
        res.passed = True
        res.details.append("Negative case: conversational answer (no tool call)")
        return res

    # ---- Positive case: expected at least one tool call -------------------
    if not tool_calls:
        # No tool calls -- classify the failure mode
        mode, evidence = classify_no_tool_response(content)
        res.failure_mode = mode
        res.details.append(f"No tool_calls field. {evidence}")
        return res

    # We have tool_calls. Check forbidden tools first.
    called_names = [tc.get("function", {}).get("name") for tc in tool_calls]
    forbidden_hit = [n for n in called_names if n in forbidden_tools]
    if forbidden_hit:
        res.failure_mode = "FORBIDDEN_TOOL"
        res.details.append(f"Called forbidden tool(s): {forbidden_hit}")
        return res

    # Check expected tools are present.
    missing_tools = [t for t in expected_tools if t not in called_names]
    if missing_tools:
        res.failure_mode = "WRONG_TOOL"
        res.details.append(
            f"Expected tools {expected_tools}, got {called_names}. Missing: {missing_tools}"
        )
        return res

    # All expected tools present. Now check each tool's args.
    arg_failures: list[str] = []
    for tool_name, checkers in expected_args.items():
        # Find the (first) call to this tool.
        call = next(
            (tc for tc in tool_calls if tc.get("function", {}).get("name") == tool_name),
            None,
        )
        if call is None:
            arg_failures.append(f"{tool_name}: no call found (should be unreachable)")
            continue

        args_raw = call.get("function", {}).get("arguments", "{}")
        if isinstance(args_raw, str):
            try:
                args = json.loads(args_raw)
            except json.JSONDecodeError as e:
                arg_failures.append(f"{tool_name}: arguments not valid JSON: {e}")
                continue
        elif isinstance(args_raw, dict):
            args = args_raw
        else:
            arg_failures.append(f"{tool_name}: arguments has unexpected type {type(args_raw).__name__}")
            continue

        for arg_name, checker in checkers.items():
            actual = args.get(arg_name)
            ok, msg = check_arg(actual, checker)
            if not ok:
                arg_failures.append(f"{tool_name}.{arg_name}: {msg}")

    if arg_failures:
        # Heuristic: classify as Mode B if any failure looks like truncation.
        # Truncation signature: actual value is a strict prefix/suffix of expected,
        # OR a contains_all check failed because some substrings are missing.
        looks_like_B = any(
            "contains_all" in f or "exact:" in f for f in arg_failures
        )
        res.failure_mode = "B" if looks_like_B else "WRONG_ARGS"
        res.details.extend(arg_failures)
        return res

    # All checks passed.
    res.passed = True
    res.details.append(f"Called {called_names} with valid args")
    return res
