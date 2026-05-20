"""
Markdown scorecard generator for WireClaw bench results.
"""
from __future__ import annotations


def render(run: dict) -> str:
    """Render a full bench run as a Markdown report."""
    out: list[str] = []
    out.append(f"# WireClaw Tool-Calling Bench")
    out.append("")
    out.append(f"- **Timestamp (UTC):** {run['timestamp_utc']}")
    out.append(f"- **Endpoint:** `{run['endpoint']}`")
    out.append(f"- **Prompt variant:** `{run['prompt_variant']}` ({run['prompt_chars']} chars)")
    out.append(f"- **Tools variant:** `{run['tools_variant']}` ({run['tools_count']} tools)")
    out.append(f"- **Test cases:** {run['cases_count']}")
    out.append("")

    out.append("## Summary")
    out.append("")
    out.append("| Model | Pass | Mode A (leak) | Mode B (trunc) | Mode C (XML) | Mode D (drown) | Wrong Tool | Wrong Args | Forbidden | API Err | Avg Latency |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for m in run["models"]:
        s = m["summary"]
        modes = s["failure_modes"]
        out.append(
            f"| `{m['model']}` "
            f"| **{s['pass_count']}/{s['total']}** ({s['pass_rate']*100:.0f}%) "
            f"| {modes.get('A', 0)} "
            f"| {modes.get('B', 0)} "
            f"| {modes.get('C', 0)} "
            f"| {modes.get('D', 0)} "
            f"| {modes.get('WRONG_TOOL', 0)} "
            f"| {modes.get('WRONG_ARGS', 0)} "
            f"| {modes.get('FORBIDDEN_TOOL', 0)} "
            f"| {modes.get('API_ERROR', 0)} "
            f"| {s['avg_latency_ms']}ms |"
        )
    out.append("")

    # Per-test pass matrix
    out.append("## Pass Matrix")
    out.append("")
    if run["models"]:
        case_ids = [c["case_id"] for c in run["models"][0]["cases"]]
        header = "| Case | " + " | ".join(f"`{m['model'][:20]}`" for m in run["models"]) + " |"
        out.append(header)
        out.append("|" + "---|" * (len(run["models"]) + 1))
        for i, cid in enumerate(case_ids):
            row = [f"`{cid}`"]
            for m in run["models"]:
                c = m["cases"][i]
                if c["passed"]:
                    row.append("PASS")
                else:
                    row.append(f"**{c['failure_mode']}**")
            out.append("| " + " | ".join(row) + " |")
    out.append("")

    # Detailed failures per model
    out.append("## Failure Details")
    out.append("")
    for m in run["models"]:
        out.append(f"### `{m['model']}`")
        out.append("")
        any_fail = False
        for c in m["cases"]:
            if c["passed"]:
                continue
            any_fail = True
            out.append(f"**`{c['case_id']}`** — Mode `{c['failure_mode']}` ({c['latency_ms']}ms)")
            out.append(f"> Prompt: {c['prompt']}")
            out.append(f"> Expected tools: `{c['expected_tools']}`")
            for d in c["details"]:
                out.append(f"- {d}")
            if c["tool_calls"]:
                out.append("- Tool calls observed:")
                out.append("  ```json")
                import json as _json
                for tc in c["tool_calls"]:
                    out.append("  " + _json.dumps(tc, indent=2).replace("\n", "\n  "))
                out.append("  ```")
            if c["content"] and c["failure_mode"] in ("A", "C", "D"):
                snippet = c["content"][:400].replace("\n", " ")
                out.append(f"- Content snippet: `{snippet}`")
            out.append("")
        if not any_fail:
            out.append("_All cases passed._")
            out.append("")

    out.append("---")
    out.append("")
    out.append("*Mode legend:*")
    out.append("- **A** = text leak (tool intent in prose / fenced JSON instead of `tool_calls`)")
    out.append("- **B** = argument abbreviation / truncation in a structurally valid call")
    out.append("- **C** = XML tool-call format (`<tool_call>`) instead of JSON `tool_calls`")
    out.append("- **D** = no tool call, no leak markers; model just chatted")
    out.append("- **WRONG_TOOL** = called a tool but not the expected one")
    out.append("- **WRONG_ARGS** = right tool, wrong args (and not classifiable as B)")
    out.append("- **FORBIDDEN_TOOL** = called a tool the case explicitly forbids")
    out.append("- **API_ERROR** = HTTP/transport failure")
    out.append("")
    return "\n".join(out)
