#!/bin/bash
# N5 diagnostic: why don't assistant tool_calls render? Inspect the Llama 3.1
# chat_template's tool handling and try the documented tool-call shapes.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json
from transformers import AutoTokenizer
tok=AutoTokenizer.from_pretrained("NousResearch/Meta-Llama-3.1-8B-Instruct")

TD='fork/lora/training-data'
cap=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-captured.jsonl',encoding='utf-8')]
ex=next(e for e in cap if e['messages'][-1].get('tool_calls'))
am=ex['messages'][-1]
print("assistant msg shape we ship:")
print(json.dumps(am,indent=1)[:500])

# 1) Does the template mention tool_calls at all?
ct=tok.chat_template or ""
print("\nchat_template references: tool_calls=%s  function=%s  python_tag=%s  ipython=%s"
      % ('tool_calls' in ct, 'function' in ct, 'python_tag' in ct, 'ipython' in ct))

# 2) Correct token length (my earlier len() was on a bad call)
ids=tok.apply_chat_template(ex['messages'], tokenize=True)
txt=tok.apply_chat_template(ex['messages'], tokenize=False)
print(f"\ntoken length (correct) = {len(ids)} ; text chars = {len(txt)}")

# 3) Does the tail contain the tool call?
print("has 'gpio_write' in rendered text:", 'gpio_write' in txt,
      "| has python_tag:", '<|python_tag|>' in txt)
print("TAIL 600:\n", txt[-600:])

# 4) Llama 3.1 template renders assistant tool_calls only when the
#    arguments are a dict (not a JSON string) per the official template.
import copy
alt=copy.deepcopy(ex['messages'])
for tc in alt[-1]['tool_calls']:
    tc['function']['arguments']=json.loads(tc['function']['arguments'])  # dict, not str
try:
    t2=tok.apply_chat_template(alt, tokenize=False)
    print("\n[ALT: arguments as DICT] has gpio_write:", 'gpio_write' in t2,
          "python_tag:", '<|python_tag|>' in t2)
    print("ALT TAIL 500:\n", t2[-500:])
except Exception as e:
    print("ALT render error:", str(e)[:200])
EOF
