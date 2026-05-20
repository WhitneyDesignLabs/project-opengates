#!/bin/bash
# Phase 3.2 step 1b N2: two back-to-back judge calls; verify ephemeral cache
# engages (call1 cache_creation_input_tokens>0, call2 cache_read_input_tokens>0).
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2

python3 - <<'EOF'
import json, anthropic, wrap_up_classify as w
d=json.load(open('fork/lora/corpus-raw/3.1.3-2026-05-16-pilot.json'))
c0=w.normalize_conversation(d['conversations'][0])
c1=w.normalize_conversation(d['conversations'][1])
client=anthropic.Anthropic()

def call(conv, tag):
    m=client.messages.create(
        model=w.HAIKU_MODEL, max_tokens=256,
        system=[{"type":"text","text":w.JUDGE_SYSTEM_PROMPT,
                 "cache_control":{"type":"ephemeral"}}],
        messages=[{"role":"user","content":w.build_judge_user_message(conv)}],
    )
    u=m.usage
    print(f"{tag}: in={u.input_tokens} out={u.output_tokens} "
          f"cache_create={getattr(u,'cache_creation_input_tokens',None)} "
          f"cache_read={getattr(u,'cache_read_input_tokens',None)}")
    return u

u1=call(c0,"call1")
u2=call(c1,"call2")
cc=getattr(u1,'cache_creation_input_tokens',0) or 0
cr=getattr(u2,'cache_read_input_tokens',0) or 0
print()
print("VERDICT:", "PASS - caching engaged" if (cc>0 and cr>0)
      else "FAIL - caching NOT engaging (debug before parallel run)")
EOF
