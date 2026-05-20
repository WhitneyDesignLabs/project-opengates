#!/bin/bash
# Phase 3.2 N1: load ANTHROPIC_API_KEY from Secrets.txt (only that line, not
# whole-file source), ensure anthropic SDK, one cheap sanity call. No key echo.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"

# Secrets.txt holds the key as a bare `sk-ant-...` line (not KEY=val form).
# Accept either: an ANTHROPIC_API_KEY=... line OR the first bare sk-ant- token.
val=$(grep -E '^[[:space:]]*(export[[:space:]]+)?ANTHROPIC_API_KEY=' "$SECRETS" 2>/dev/null \
        | head -1 | sed -E 's/^[^=]*=//')
if [ -z "$val" ]; then
  val=$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" 2>/dev/null | head -1)
fi
val=$(printf %s "$val" | tr -d '\r' | sed -E 's/^["'\'']//; s/["'\'']$//')
if [ -z "$val" ]; then echo "FATAL: no key found in Secrets.txt"; exit 2; fi
export ANTHROPIC_API_KEY="$val"
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then echo "FATAL: parsed empty key"; exit 2; fi
echo "key loaded: ${ANTHROPIC_API_KEY:0:12}... (len ${#ANTHROPIC_API_KEY})"

echo "== ensure anthropic SDK =="
if ! python3 -c "import anthropic" 2>/dev/null; then
  python3 -m pip install --quiet --user anthropic 2>&1 | tail -3
fi
python3 -c "import anthropic; print('anthropic SDK', anthropic.__version__)" || { echo "FATAL: SDK still missing"; exit 3; }

echo "== sanity call (1 cheap Haiku message) =="
python3 -c "
import anthropic
c=anthropic.Anthropic()
r=c.messages.create(model='claude-haiku-4-5-20251001', max_tokens=10,
    messages=[{'role':'user','content':'reply with the single word OK'}])
print('API ok ->', r.content[0].text)
print('usage  ->', r.usage)
"
