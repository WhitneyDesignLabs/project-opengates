#!/bin/bash
# Why is ephemeral caching not engaging? Hypothesis: JUDGE_SYSTEM_PROMPT is
# far below Haiku's minimum cacheable prompt size (~2048 tok for Haiku tier).
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import anthropic, wrap_up_classify as w
client=anthropic.Anthropic()
# Count tokens of the system prompt alone.
ct=client.messages.count_tokens(
    model=w.HAIKU_MODEL,
    system=[{"type":"text","text":w.JUDGE_SYSTEM_PROMPT}],
    messages=[{"role":"user","content":"x"}],
)
print("JUDGE_SYSTEM_PROMPT chars:", len(w.JUDGE_SYSTEM_PROMPT))
print("count_tokens (system + 'x'):", ct)
print()
print("Anthropic min cacheable prompt: Haiku tier = 2048 tokens "
      "(Sonnet/Opus = 1024). cache_control is accepted but SILENTLY no-ops "
      "below the minimum -> cache_creation/read stay 0, no error.")
print("=> system prompt (~hundreds of tok) << 2048 => caching physically "
      "cannot engage at this prompt size. Not an SDK/format bug.")
EOF
