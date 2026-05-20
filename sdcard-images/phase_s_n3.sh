#!/bin/bash
# Phase 3.2 N3: 681 clean-pool turns -> HF SFT messages JSONL, SOUL-LOCAL system.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json
TD='fork/lora/training-data'
soul_local_raw=open(f'{TD}/constitution/SOUL-LOCAL.md',encoding='utf-8').read()
# Strip leading "# " comment lines (per directive); body lines start with digits.
soul=( "\n".join(l for l in soul_local_raw.splitlines()
                  if not l.startswith("# ")) ).strip()
print(f"SOUL-LOCAL: raw {len(soul_local_raw)} bytes -> system msg {len(soul)} chars "
      f"({len(soul.encode())} bytes), {len(soul.splitlines())} lines")

out=open(f'{TD}/wireclaw-v1-captured.jsonl','w',encoding='utf-8')
meta=open(f'{TD}/wireclaw-v1-captured.meta.jsonl','w',encoding='utf-8')
n=0; skipped=0; empty_tc=0; with_tc=0
for line in open(f'{TD}/clean-pool.jsonl',encoding='utf-8'):
    t=json.loads(line)
    msgs=[{"role":"system","content":soul},
          {"role":"user","content":t["prompt"]}]
    am={"role":"assistant","content":t["response"]}
    tcs=t.get("tool_calls") or []
    conv=[]
    bad=False
    for tc in tcs:
        fn=tc.get("function")
        if isinstance(fn,dict): fn=fn.get("name")
        args=tc.get("arguments")
        if not isinstance(fn,str) or not fn:
            bad=True; break
        if not isinstance(args,(dict,list)): args={}
        conv.append({"type":"function",
                     "function":{"name":fn,"arguments":json.dumps(args)}})
    if bad:
        skipped+=1; continue
    if conv:
        am["tool_calls"]=conv; with_tc+=1
    else:
        empty_tc+=1   # no tool_calls field at all
    msgs.append(am)
    out.write(json.dumps({"messages":msgs},ensure_ascii=False)+"\n")
    meta.write(json.dumps({"id":t["id"],"persona":t["persona"],
                           "chip":t["chip"],"source":"captured"},
                          ensure_ascii=False)+"\n")
    n+=1
out.close(); meta.close()
print(f"N3: wrote {n} captured examples (with_tool_calls={with_tc}, "
      f"no_tool_calls_field={empty_tc}); skipped_malformed={skipped}")
print(f"  -> {TD}/wireclaw-v1-captured.jsonl (+ .meta.jsonl)")
# quick schema sanity
import itertools
s=json.loads(open(f'{TD}/wireclaw-v1-captured.jsonl').readline())
print("sample roles:",[m["role"] for m in s["messages"]],
      "| assistant has tool_calls:", "tool_calls" in s["messages"][-1])
EOF
