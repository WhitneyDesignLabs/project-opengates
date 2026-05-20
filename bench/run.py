#!/usr/bin/env python3
"""
WireClaw tool-calling bench runner.

Sends WireClaw-shaped chat-completions requests to an OpenAI-compatible
endpoint (Ollama, OpenRouter, etc.), runs each model through the test suite
in test_cases.yaml, and classifies failures by mode.

Usage:
  python run.py --endpoint http://azza.tail63f48.ts.net:11434 \\
                --models opengates-agent:v1 qwen3-nothinker:latest qwen3:8b

  # Variants:
  python run.py --endpoint <url> --models <list> --prompt full
  python run.py --endpoint <url> --models <list> --tools examples
  python run.py --endpoint <url> --models <list> --prompt full --tools examples

  # Streaming probe (control test: confirms stream=true silently drops tool_calls):
  python run.py --endpoint <url> --models opengates-agent:v1 --probe-streaming

Output:
  results/run-<ISO timestamp>.json   -- full raw results
  results/run-<ISO timestamp>.md     -- human-readable scorecard

Request shape matches WireClaw firmware exactly (src/llm_client.cpp:238-321):
  {
    "model": "<model>",
    "messages": [...],
    "tools": [...],
    "tool_choice": "auto",
    "max_tokens": 2048,
    "temperature": 0.7
  }
No 'stream' key (defaults to false). No 'num_ctx', 'keep_alive', etc.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
from pathlib import Path

import requests
import yaml

from classify import classify_case, init_tool_names

HERE = Path(__file__).parent
DATA = HERE / "wireclaw_data"
RESULTS = HERE / "results"

# Request shape matches WireClaw firmware buildRequest():
# src/llm_client.cpp:243-319
# Hardcoded values: max_tokens=2048, temperature=0.7, no stream key.
WIRECLAW_MAX_TOKENS = 2048
WIRECLAW_TEMPERATURE = 0.7


def load_system_prompt(variant: str) -> str:
    path = DATA / f"system_prompt_{variant}.txt"
    if not path.exists():
        raise SystemExit(f"Unknown prompt variant: {variant} (expected file {path})")
    return path.read_text()


def load_tools(variant: str) -> list[dict]:
    path = DATA / f"tools_{variant}.json"
    if not path.exists():
        raise SystemExit(f"Unknown tools variant: {variant} (expected file {path})")
    return json.loads(path.read_text())


def load_test_cases() -> list[dict]:
    path = HERE / "test_cases.yaml"
    return yaml.safe_load(path.read_text())["cases"]


def build_messages(system_prompt: str, case: dict) -> list[dict]:
    """Build messages array in WireClaw style: system + (optional pre_messages) + user."""
    msgs = [{"role": "system", "content": system_prompt}]
    for pre in case.get("pre_messages") or []:
        msgs.append(pre)
    msgs.append({"role": "user", "content": case["prompt"]})
    return msgs


def send_request(
    endpoint: str,
    model: str,
    messages: list[dict],
    tools: list[dict],
    *,
    stream: bool = False,
    timeout: int = 180,
) -> tuple[dict, int, str | None]:
    """
    POST a chat-completions request. Returns (response_dict, latency_ms, error).
    On error, response_dict is empty and error is a string.
    """
    url = endpoint.rstrip("/") + "/v1/chat/completions"
    body = {
        "model": model,
        "messages": messages,
        "tools": tools,
        "tool_choice": "auto",
        "max_tokens": WIRECLAW_MAX_TOKENS,
        "temperature": WIRECLAW_TEMPERATURE,
    }
    if stream:
        body["stream"] = True

    t0 = time.monotonic()
    try:
        if stream:
            # For streaming probe: accumulate the stream and decode.
            r = requests.post(url, json=body, timeout=timeout, stream=True)
            r.raise_for_status()
            chunks = []
            for line in r.iter_lines():
                if not line:
                    continue
                if line.startswith(b"data: "):
                    line = line[6:]
                if line.strip() == b"[DONE]":
                    break
                try:
                    chunks.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
            latency_ms = int((time.monotonic() - t0) * 1000)
            return ({"stream_chunks": chunks}, latency_ms, None)

        r = requests.post(url, json=body, timeout=timeout)
        latency_ms = int((time.monotonic() - t0) * 1000)
        if r.status_code != 200:
            return ({}, latency_ms, f"HTTP {r.status_code}: {r.text[:300]}")
        return (r.json(), latency_ms, None)
    except requests.RequestException as e:
        latency_ms = int((time.monotonic() - t0) * 1000)
        return ({}, latency_ms, f"RequestException: {e}")
    except json.JSONDecodeError as e:
        latency_ms = int((time.monotonic() - t0) * 1000)
        return ({}, latency_ms, f"JSONDecodeError: {e}")


def extract_message(response: dict) -> dict:
    """Pull message object from a non-streaming chat-completions response."""
    try:
        return response["choices"][0]["message"]
    except (KeyError, IndexError, TypeError):
        return {"role": "assistant", "content": "", "tool_calls": []}


def run_bench(
    endpoint: str,
    models: list[str],
    prompt_variant: str,
    tools_variant: str,
    cases: list[dict],
    timeout: int,
    verbose: bool = False,
) -> dict:
    system_prompt = load_system_prompt(prompt_variant)
    tools = load_tools(tools_variant)
    init_tool_names([t["function"]["name"] for t in tools])

    run = {
        "schema": "wireclaw-bench/v1",
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "endpoint": endpoint,
        "prompt_variant": prompt_variant,
        "tools_variant": tools_variant,
        "prompt_chars": len(system_prompt),
        "tools_count": len(tools),
        "cases_count": len(cases),
        "models": [],
    }

    for model in models:
        print(f"\n=== Model: {model} ({prompt_variant} prompt, {tools_variant} tools) ===")
        model_result = {
            "model": model,
            "cases": [],
            "summary": {},
        }
        for case in cases:
            print(f"  [{case['id']}] {case['prompt'][:70]}", end="", flush=True)
            messages = build_messages(system_prompt, case)
            response, latency_ms, error = send_request(
                endpoint, model, messages, tools, timeout=timeout
            )
            msg = extract_message(response) if not error else {}
            result = classify_case(case, msg, api_error=error)
            result.latency_ms = latency_ms
            result.raw_response = response

            print(
                f"  -> {'PASS' if result.passed else 'FAIL'}"
                f" {'(' + result.failure_mode + ')' if not result.passed else ''}"
                f"  {latency_ms}ms"
            )
            if verbose and not result.passed:
                for d in result.details:
                    print(f"      {d}")

            model_result["cases"].append({
                "case_id": result.case_id,
                "passed": result.passed,
                "failure_mode": result.failure_mode,
                "details": result.details,
                "latency_ms": result.latency_ms,
                "tool_calls": result.tool_calls_observed,
                "content": result.content_observed,
                "prompt": case["prompt"],
                "expected_tools": case.get("expected_tools", []),
                "raw_response": result.raw_response,
            })

        # Per-model summary
        cases_data = model_result["cases"]
        passed = sum(1 for c in cases_data if c["passed"])
        modes: dict[str, int] = {}
        for c in cases_data:
            if not c["passed"]:
                modes[c["failure_mode"]] = modes.get(c["failure_mode"], 0) + 1
        latencies = [c["latency_ms"] for c in cases_data if c["latency_ms"] > 0]
        avg_latency = sum(latencies) / len(latencies) if latencies else 0
        model_result["summary"] = {
            "pass_count": passed,
            "total": len(cases_data),
            "pass_rate": passed / len(cases_data) if cases_data else 0,
            "failure_modes": modes,
            "avg_latency_ms": int(avg_latency),
            "total_time_s": sum(latencies) / 1000,
        }
        print(f"  --- {passed}/{len(cases_data)} pass, modes={modes}, avg {int(avg_latency)}ms ---")

        run["models"].append(model_result)

    return run


def probe_streaming(endpoint: str, model: str, timeout: int = 60) -> dict:
    """
    Control test: confirm stream=true silently drops tool_calls on Ollama.
    Documents the Mode E failure mode that Scott's primer flagged.
    """
    print(f"\n=== Streaming probe: {model} ===")
    system_prompt = load_system_prompt("truncated")
    tools = load_tools("stock")
    init_tool_names([t["function"]["name"] for t in tools])

    case = {
        "id": "PROBE_STREAMING",
        "prompt": "Set the LED to red.",
        "expected_tools": ["led_set"],
        "expected_args": {"led_set": {"r": {"exact": 255}, "g": {"exact": 0}, "b": {"exact": 0}}},
    }
    messages = build_messages(system_prompt, case)

    print("  stream=false (baseline):", end=" ", flush=True)
    r_false, lat_false, err_false = send_request(
        endpoint, model, messages, tools, stream=False, timeout=timeout
    )
    msg_false = extract_message(r_false) if not err_false else {}
    tc_false = msg_false.get("tool_calls") or []
    print(f"tool_calls={len(tc_false)} latency={lat_false}ms")

    print("  stream=true (probe): ", end=" ", flush=True)
    r_true, lat_true, err_true = send_request(
        endpoint, model, messages, tools, stream=True, timeout=timeout
    )
    # Aggregate tool_calls from stream chunks.
    chunks = r_true.get("stream_chunks", []) if not err_true else []
    streamed_tool_calls = []
    for ch in chunks:
        try:
            delta = ch["choices"][0]["delta"]
        except (KeyError, IndexError, TypeError):
            continue
        if "tool_calls" in delta:
            streamed_tool_calls.append(delta["tool_calls"])
    print(f"chunks={len(chunks)} tool_call_deltas={len(streamed_tool_calls)} latency={lat_true}ms")

    return {
        "model": model,
        "stream_false": {
            "tool_calls_count": len(tc_false),
            "latency_ms": lat_false,
            "error": err_false,
        },
        "stream_true": {
            "chunks": len(chunks),
            "tool_call_deltas": len(streamed_tool_calls),
            "latency_ms": lat_true,
            "error": err_true,
        },
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--endpoint", required=True, help="Base URL, e.g. http://azza.tail63f48.ts.net:11434")
    ap.add_argument("--models", nargs="+", required=True, help="One or more model names")
    ap.add_argument("--prompt", default="truncated",
                    help="Prompt variant name; loads wireclaw_data/system_prompt_<variant>.txt (default: truncated)")
    ap.add_argument("--tools", default="stock",
                    help="Tools variant name; loads wireclaw_data/tools_<variant>.json (default: stock)")
    ap.add_argument("--timeout", type=int, default=180, help="Per-request timeout in seconds")
    ap.add_argument("--verbose", "-v", action="store_true", help="Print failure details inline")
    ap.add_argument("--probe-streaming", action="store_true",
                    help="Run streaming-vs-not control test. Only first model used.")
    ap.add_argument("--out", help="Output file basename (default: run-<timestamp>)")
    args = ap.parse_args()

    RESULTS.mkdir(exist_ok=True)
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    basename = args.out or f"run-{timestamp}"

    if args.probe_streaming:
        probe = probe_streaming(args.endpoint, args.models[0], timeout=args.timeout)
        out_json = RESULTS / f"{basename}-streaming-probe.json"
        out_json.write_text(json.dumps(probe, indent=2))
        print(f"\nWrote {out_json}")
        return

    cases = load_test_cases()
    run = run_bench(
        endpoint=args.endpoint,
        models=args.models,
        prompt_variant=args.prompt,
        tools_variant=args.tools,
        cases=cases,
        timeout=args.timeout,
        verbose=args.verbose,
    )

    out_json = RESULTS / f"{basename}.json"
    out_json.write_text(json.dumps(run, indent=2, default=str))
    print(f"\nWrote {out_json}")

    # Auto-generate markdown report.
    try:
        from report import render
        out_md = RESULTS / f"{basename}.md"
        out_md.write_text(render(run))
        print(f"Wrote {out_md}")
    except Exception as e:
        print(f"(Report generation failed: {e})")


if __name__ == "__main__":
    main()
