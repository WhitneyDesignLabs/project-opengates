#!/usr/bin/env python3
"""Phase 4.4.0.E.2 A/B driver. Adapted from phase_4_3_0h_ab_driver.py.

Runs ON evobot Pi (uses its phase31-venv telethon + .telethon-evobot.session).
Sends each curated prompt 5x to wdl_c6_pilot_bot via Telegram.

CHANGE vs 4.3.0.H driver (the 4.4.0.0 item-3 methodology fix):
  - PER-RUN reset. /clear (history) + rules-delete + memory-reset now happen
    before EVERY run, not just once per prompt. This yields genuinely
    independent samples instead of history-anchored ones. Adds ~3s/run wall.

Arm semantics for 4.4.0.E.2:
  control   <=> wireclaw-agent:v1.3.1   (production baseline)
  treatment <=> wireclaw-agent:v1.3.2   (action-claim-suppression LoRA)
Both arms: firmware 7432edde (v0.4.0), wrap_mode=speculative. The chip's
`model` config field is set externally by phase_4_4_0e_flip_chip.sh before
each arm runs. The `arm` metadata field is just a label here.

Metadata output: ~/phase_4_4_0e_ab_metadata.jsonl (separate from H's).
"""
from __future__ import annotations
import argparse, asyncio, datetime as dt, json, os, sys, urllib.request, urllib.parse
from pathlib import Path

CHIP_IP = "192.168.1.19"
BOT_USERNAME = "wdl_c6_pilot_bot"
SESSION = str(Path.home() / ".telethon-evobot.session")
PROMPTS_FILE = Path.home() / "phase_4_3_0_ab_prompts.jsonl"  # same 28 prompts
META_OUT = Path.home() / "phase_4_4_0e_ab_metadata.jsonl"

MEMORY_SEED = "favorite_color=green"
REPLY_TIMEOUT_S = 60.0
SETTLE_S = 8.0
INTERPROMPT_S = 2.0
RUNS_PER_PROMPT = 5


def is_substantive(text: str) -> bool:
    if not text:
        return False
    t = text.strip()
    if not t:
        return False
    low = t.lower()
    if "history cleared" in low and len(t) < 40:
        return False
    if t.startswith("[Agent]") or t.startswith("[TG]"):
        return False
    if "wireclaw v0." in low and "started" in low:
        return False
    return True


def http_post(url: str, body: dict | None = None, timeout: float = 10.0):
    data = json.dumps(body).encode() if body is not None else b""
    req = urllib.request.Request(url, data=data, method="POST",
                                  headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode(errors="replace")
    except Exception as e:
        return f"[err:{e}]"


def reset_chip_state():
    rules_resp = http_post(f"http://{CHIP_IP}/api/rules/delete", {"id": "all"})
    mem_resp = http_post(f"http://{CHIP_IP}/api/memory", MEMORY_SEED)
    return rules_resp, mem_resp


async def main_async(arm: str):
    from telethon import TelegramClient, events

    api_id = int(os.environ["TG_API_ID"])
    api_hash = os.environ["TG_API_HASH"]
    phone = os.environ["TG_PHONE"]

    prompts = []
    with PROMPTS_FILE.open() as f:
        for line in f:
            line = line.strip()
            if line:
                prompts.append(json.loads(line))
    print(f"loaded {len(prompts)} prompts; arm={arm}")
    print(f"chip ip {CHIP_IP}, bot {BOT_USERNAME}, runs/prompt {RUNS_PER_PROMPT}")
    print("PER-RUN reset ENABLED (4.4.0.E.2 methodology fix)")

    client = TelegramClient(SESSION, api_id, api_hash)
    await client.start(phone=phone)

    bot = await client.get_entity(BOT_USERNAME)
    print(f"connected; bot entity id={bot.id}")

    reply_buf: list[tuple[float, str]] = []
    first_reply_evt: asyncio.Event = asyncio.Event()

    @client.on(events.NewMessage(from_users=bot.id))
    async def on_reply(event):
        text = event.raw_text or ""
        if is_substantive(text):
            reply_buf.append((asyncio.get_event_loop().time(), text))
            if not first_reply_evt.is_set():
                first_reply_evt.set()

    meta = META_OUT.open("a")

    for p_idx, p in enumerate(prompts):
        prompt_id = p["id"]
        bucket = p["bucket"]
        prompt = p["prompt"]
        print(f"\n[{p_idx+1}/{len(prompts)}] {prompt_id} bucket={bucket}  {prompt[:70]!r}")

        for run in range(1, RUNS_PER_PROMPT + 1):
            # per-run reset (NEW vs 4.3.0.H driver) — independent samples
            await client.send_message(bot, "/clear")
            await asyncio.sleep(2.0)
            rr, mr = reset_chip_state()
            await asyncio.sleep(1.0)
            if run == 1:
                print(f"  reset: rules={rr.strip()[:50]}  mem={mr.strip()[:50]}")

            reply_buf.clear()
            first_reply_evt.clear()
            ts_sent = dt.datetime.now(dt.timezone.utc)
            await client.send_message(bot, prompt)
            try:
                await asyncio.wait_for(first_reply_evt.wait(), timeout=REPLY_TIMEOUT_S)
            except asyncio.TimeoutError:
                print(f"    run {run}: TIMEOUT after {REPLY_TIMEOUT_S}s")
            await asyncio.sleep(SETTLE_S)
            ts_received = (reply_buf[0][0] if reply_buf else None)
            preview = (reply_buf[-1][1][:120] if reply_buf else "")
            print(f"    run {run}: msgs={len(reply_buf)} preview={preview!r}")
            meta.write(json.dumps({
                "prompt_id": prompt_id,
                "bucket": bucket,
                "arm": arm,
                "run_num": run,
                "ts_sent_iso": ts_sent.isoformat(),
                "ts_first_reply_loop": ts_received,
                "reply_msg_count": len(reply_buf),
                "reply_preview": preview,
            }) + "\n")
            meta.flush()
            await asyncio.sleep(INTERPROMPT_S)

    meta.close()
    await client.disconnect()
    print(f"\ndone. metadata appended to {META_OUT}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arm", required=True, choices=["control", "treatment"])
    args = ap.parse_args()
    asyncio.run(main_async(args.arm))


if __name__ == "__main__":
    main()
