#!/bin/bash
# Phase 3.2 N3.5: synthetic constitutional examples via Haiku for the 11
# articles not in SOUL-CHIP. Aborts on credit/4xx. Tracks token usage.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import anthropic, json, re, time, sys
TD='fork/lora/training-data'
soul=open(f'{TD}/constitution/SOUL.md',encoding='utf-8').read()
sl_raw=open(f'{TD}/constitution/SOUL-LOCAL.md',encoding='utf-8').read()
soul_local=( "\n".join(l for l in sl_raw.splitlines()
             if not l.startswith("# ")) ).strip()

ARTS=[("5","Cascading Consequence Awareness"),("6","Humility Before Limits"),
("8","Balance and Equilibrium"),("9","Long-Term Over Short-Term"),
("10","Breaking Cycles of Escalation"),("11","The Physical Domain"),
("17","Logging and Auditability"),("21","Constitutional Stability"),
("22","Growth Within Principles"),("23","Interpretation"),("24","Acknowledgment")]

# Split SOUL.md into article blocks by "### Article N:" headers.
hdr=re.compile(r'^### Article (\d+):\s*(.*)$')
lines=soul.splitlines(); blocks={}; cur=None; buf=[]
for ln in lines:
    m=hdr.match(ln)
    if m:
        if cur is not None: blocks[cur]="\n".join(buf).strip()
        cur=m.group(1); buf=[ln]
    elif cur is not None:
        if ln.startswith('## ') and not ln.startswith('### '):
            blocks[cur]="\n".join(buf).strip(); cur=None; buf=[]
        else: buf.append(ln)
if cur is not None: blocks[cur]="\n".join(buf).strip()

GEN='''You are generating training data for WireClaw-Agent, a constitutional AI agent running on an ESP32-C6 microcontroller. The agent controls GPIO pins, an RGB LED, sensors, automation rules, and a small memory file (/memory.txt). It governs itself by SOUL.md.

Generate 8 diverse training examples that exercise this specific article's principle:

%s

Each example is a complete (user message, assistant response) pair.
Diversity guidance:
- Mix clear cases with borderline cases
- Some examples should be situations where the article informs HOW the agent does something (not just refusals)
- Some can include tool_calls; some shouldn't need any
- User messages should sound like real Telegram messages someone might send a smart-home agent (terse, conversational, or technical)
- Assistant responses should demonstrate adherence to the article through behavior — not by quoting the article text directly
- Refusals should cite the article BY NUMBER (e.g., "I can't do that per Article 3...") — but most examples shouldn't be refusals

Output as a JSON array of 8 objects:
[{"user":"<user message>","assistant_content":"<wrap-up text>","tool_calls":[{"name":"led_set","arguments":{"r":255,"g":0,"b":0}}]}]
tool_calls is optional; omit if no tools needed. Return ONLY the JSON array, no preamble.'''

client=anthropic.Anthropic()
syn=[]; meta=[]; tin=tout=0; fails=[]
for num,name in ARTS:
    art=blocks.get(num)
    if not art:
        fails.append((num,"article text not found in SOUL.md")); continue
    try:
        r=client.messages.create(model="claude-haiku-4-5-20251001",
            max_tokens=4000,
            messages=[{"role":"user","content":GEN % art}])
    except Exception as e:
        msg=str(e)
        print(f"ABORT art{num}: API error: {msg[:200]}")
        if '400' in msg or 'credit' in msg.lower() or '401' in msg:
            print("CREDIT/AUTH error -> stopping (per directive)"); break
        fails.append((num,f"api:{msg[:120]}")); continue
    u=r.usage; tin+=u.input_tokens; tout+=u.output_tokens
    txt="".join(b.text for b in r.content if getattr(b,'type',None)=='text').strip()
    mm=re.search(r'\[.*\]', txt, re.DOTALL)
    if not mm:
        fails.append((num,"no JSON array in output")); time.sleep(0.5); continue
    try:
        arr=json.loads(mm.group(0))
    except Exception as e:
        fails.append((num,f"bad JSON: {e}")); time.sleep(0.5); continue
    kept=0
    for ex in arr:
        if not isinstance(ex,dict) or 'user' not in ex or 'assistant_content' not in ex:
            continue
        am={"role":"assistant","content":ex["assistant_content"]}
        tcs=ex.get("tool_calls")
        if tcs:
            conv=[]
            ok=True
            for tc in tcs:
                fn=tc.get("name") or (tc.get("function") or {}).get("name")
                ar=tc.get("arguments",{})
                if not fn: ok=False; break
                conv.append({"type":"function","function":{"name":fn,"arguments":json.dumps(ar)}})
            if ok and conv: am["tool_calls"]=conv
        syn.append({"messages":[{"role":"system","content":soul_local},
                                {"role":"user","content":ex["user"]}, am]})
        meta.append({"source":f"synthetic-art{num}","article":num})
        kept+=1
    print(f"art{num} ({name}): got {len(arr)} -> kept {kept}  [in={u.input_tokens} out={u.output_tokens}]")
    time.sleep(0.5)

with open(f'{TD}/wireclaw-v1-synthetic.jsonl','w',encoding='utf-8') as f:
    for e in syn: f.write(json.dumps(e,ensure_ascii=False)+"\n")
with open(f'{TD}/wireclaw-v1-synthetic.meta.jsonl','w',encoding='utf-8') as f:
    for i,m in enumerate(meta): f.write(json.dumps({"index":i,**m})+"\n")

cost=tin/1e6*1.0 + tout/1e6*5.0
import collections
print(f"\nN3.5: {len(syn)} synthetic examples across "
      f"{len(set(m['article'] for m in meta))}/11 articles")
print("per-article:",dict(collections.Counter(m['article'] for m in meta)))
print(f"tokens in={tin} out={tout}  est_cost=${cost:.3f}  (exact: console usage)")
print("failures:",fails if fails else "none")
print("\n-- spot-check 4 --")
for e in (syn[:2]+syn[-2:]):
    print(" U:",e["messages"][1]["content"][:90])
    print(" A:",e["messages"][2]["content"][:120],
          "| tc:",[c["function"]["name"] for c in e["messages"][2].get("tool_calls",[])])
EOF
