#!/usr/bin/env python3
"""
One-time Telethon session authenticator for the WireClaw capture fleet.

The directive's H4 step assumed `persona_runner.py --dry-run` authenticates
the Telethon session; it does NOT (dry_run() returns before any Telegram
contact -- see persona_runner.py:254-255). persona_runner has no "auth-only"
mode: --dry-run = no Telegram at all; non-dry-run = fires the full battery.

This script is the missing auth-only mode: it connects as the user account,
performs the interactive first-run auth (SMS code, + 2FA password if the
account has it), persists the session to ~/.telethon-evobot.session, and
exits WITHOUT sending any prompts or touching the chip. After this runs once,
persona_runner.py reuses the session file non-interactively.

Env (sourced from ~/.wireclaw-secrets.env): TG_API_ID, TG_API_HASH, TG_PHONE.

Run interactively (needs a TTY for the code prompt):
  ssh -t pi02.local 'set -a; . ~/.wireclaw-secrets.env; set +a; \
      ~/phase31-venv/bin/python ~/wireclaw-phase31/bench/fork/lora/tg_auth_bootstrap.py \
      --session-file ~/.telethon-pi02.session'

--session-file lets each fleet Pi own its own Telethon session
(default keeps the historical ~/.telethon-evobot.session for back-compat).
"""
import argparse
import os
from telethon.sync import TelegramClient


def main() -> int:
    ap = argparse.ArgumentParser(description="One-time Telethon session auth.")
    ap.add_argument("--session-file", default="~/.telethon-evobot.session",
                    help="Path for the persisted Telethon session "
                         "(default: ~/.telethon-evobot.session).")
    args = ap.parse_args()
    SESSION = os.path.expanduser(args.session_file)

    try:
        api_id = int(os.environ["TG_API_ID"])
        api_hash = os.environ["TG_API_HASH"]
        phone = os.environ["TG_PHONE"]
    except KeyError as e:
        print(f"ERROR: missing env var {e}. Source ~/.wireclaw-secrets.env first.")
        return 2

    print(f"Connecting to Telegram as {phone}.")
    print("You will be prompted ONLY for the SMS login code "
          "(and your 2FA password if the account has 2FA enabled).")
    # Must call start(phone=...) explicitly. The bare `with TelegramClient(...)`
    # context manager calls start() with NO phone -> Telethon interactively
    # prompts "Please enter your phone (or bot token):", which is confusing
    # (operator types the SMS code there -> PhoneNumberInvalidError). Passing
    # phone= here makes Telethon send the code and prompt for the CODE only.
    client = TelegramClient(SESSION, api_id, api_hash)
    client.start(phone=phone)   # telethon.sync: synchronous; prompts code/2FA
    me = client.get_me()
    who = getattr(me, "username", None) or getattr(me, "id", "?")
    print(f"SESSION_AUTHED user={who} session={SESSION}")
    client.disconnect()
    print("Done. persona_runner.py will now reuse this session non-interactively.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
