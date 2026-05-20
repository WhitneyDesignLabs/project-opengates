#!/bin/bash
# Phase 3.3.1b N1: regenerate synthetic — real toolset AND <=1 tool_call per
# example. Reroll (max 2/article) on invented-name OR multi-tool violation.
set -u
SEC=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SEC" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import anthropic, json, re, time
TD='fork/lora/training-data'
soul=open(f'{TD}/constitution/SOUL.md',encoding='utf-8').read()
sl_raw=open(f'{TD}/constitution/SOUL-LOCAL.md',encoding='utf-8').read()
soul_local=("\n".join(l for l in sl_raw.splitlines() if not l.startswith("# "))).strip()
APPROVED={"led_set","gpio_write","gpio_read","temperature_read","device_info",
"device_list","device_register","sensor_read","actuator_set","file_read",
"file_write","rule_create","rule_delete","rule_enable","rule_list",
"serial_send","nats_publish","remote_chat","chain_create"}
ARTS=[("5","Cascading Consequence Awareness"),("6","Humility Before Limits"),
("8","Balance and Equilibrium"),("9","Long-Term Over Short-Term"),
("10","Breaking Cycles of Escalation"),("11","The Physical Domain"),
("17","Logging and Auditability"),("21","Constitutional Stability"),
("22","Growth Within Principles"),("23","Interpretation"),("24","Acknowledgment")]
hdr=re.compile(r'^### Article (\d+):\s*(.*)$'); blocks={}; cur=None; buf=[]
for ln in soul.splitlines():
    m=hdr.match(ln)
    if m:
        if cur is not None: blocks[cur]="\n".join(buf).strip()
        cur=m.group(1); buf=[ln]
    elif cur is not None:
        if ln.startswith('## ') and not ln.startswith('### '):
            blocks[cur]="\n".join(buf).strip(); cur=None; buf=[]
        else: buf.append(ln)
if cur is not None: blocks[cur]="\n".join(buf).strip()

TOOLS='''THE AGENT'S TOOLSET IS FIXED. Use ONLY these tools:
- led_set(r,g,b); gpio_write(pin,value); gpio_read(pin); temperature_read();
  device_info(); device_list(); device_register(name,type,pin);
  sensor_read(name); actuator_set(name,value,duration?); file_read(path);
  file_write(path,content); rule_create(...); rule_delete(rule_name);
  rule_enable(rule_name); rule_list(); serial_send(text);
  nats_publish(subject,payload); remote_chat(agent,message); chain_create(...)

DO NOT invent new tool names. If a scenario needs a missing tool, the
assistant declines (cite article by number) or recasts to available tools.

AT MOST ONE tool_call per example. If a scenario would naturally require
multiple tools, narrate the second tool's intent in the wrap-up text
(e.g., "I'll register the actuator first, then you can ask me to turn it
on") — but emit only ONE actual tool_call (or none).'''

def GEN(a):
    return f'''You are generating training data for WireClaw-Agent, a constitutional AI agent on an ESP32-C6 (GPIO, RGB LED, sensors, automation rules, /memory.txt). It governs itself by SOUL.md.

{TOOLS}

Generate 8 diverse training examples exercising this article's principle:

{a}

Guidance: mix clear/borderline; show the article informing HOW to act (not just refusals); some include ONE tool_call, some none; user messages sound like real terse/conversational/technical Telegram messages; demonstrate the principle through behavior not by quoting it; refusals MUST cite the article by number; most examples are NOT refusals.

Output ONLY a JSON array of 8 objects:
[{{"user":"...","assistant_content":"...","tool_calls":[{{"name":"<real tool>","arguments":{{}}}}]}}]
tool_calls optional, <=1 entry, omit if no tool needed. Return ONLY the JSON array.'''

client=anthropic.Anthropic()
syn=[]; meta=[]; tin=tout=0; rerolls=[]; fails=[]
for num,name in ARTS:
    art=blocks.get(num)
    if not art: fails.append((num,"no text")); continue
    ok_arr=None
    for attempt in range(3):
        try:
            r=client.messages.create(model="claude-haiku-4-5-20251001",
                max_tokens=4000, messages=[{"role":"user","content":GEN(art)}])
        except Exception as e:
            s=str(e)
            if '400' in s or 'credit' in s.lower() or '401' in s:
                print("CREDIT/AUTH abort:",s[:150]); raise SystemExit(2)
            fails.append((num,f"api {s[:80]}")); break
        tin+=r.usage.input_tokens; tout+=r.usage.output_tokens
        txt="".join(b.text for b in r.content if getattr(b,'type',None)=='text').strip()
        mm=re.search(r'\[.*\]',txt,re.DOTALL)
        if not mm: rerolls.append((num,attempt,"no JSON")); continue
        try: arr=json.loads(mm.group(0))
        except Exception as e: rerolls.append((num,attempt,f"bad JSON {e}")); continue
        bad=set(); multi=False
        for ex in arr:
            tcs=ex.get("tool_calls") or []
            if len(tcs)>1: multi=True
            for tc in tcs:
                nm=tc.get("name") or (tc.get("function") or {}).get("name")
                if nm and nm not in APPROVED: bad.add(nm)
        if bad or multi:
            rerolls.append((num,attempt,f"invented={sorted(bad)} multi={multi}")); continue
        ok_arr=arr; break
    if ok_arr is None: fails.append((num,"violation after 2 rerolls")); continue
    kept=0
    for ex in ok_arr:
        if not isinstance(ex,dict) or 'user' not in ex or 'assistant_content' not in ex: continue
        am={"role":"assistant","content":ex["assistant_content"]}
        tcs=ex.get("tool_calls") or []
        if len(tcs)>1: continue                       # safety: never emit multi
        conv=[]
        for tc in tcs[:1]:
            nm=tc.get("name") or (tc.get("function") or {}).get("name")
            if not nm or nm not in APPROVED: conv=None; break
            conv=[{"type":"function","function":{"name":nm,
                   "arguments":json.dumps(tc.get("arguments",{}))}}]
        if conv is None: continue
        if conv: am["tool_calls"]=conv
        syn.append({"messages":[{"role":"system","content":soul_local},
                                {"role":"user","content":ex["user"]},am]})
        meta.append({"source":f"synthetic-art{num}","article":num}); kept+=1
    print(f"art{num} ({name}): kept {kept}")
    time.sleep(0.5)

with open(f'{TD}/wireclaw-v1-synthetic.jsonl','w',encoding='utf-8') as f:
    for e in syn: f.write(json.dumps(e,ensure_ascii=False)+"\n")
with open(f'{TD}/wireclaw-v1-synthetic.meta.jsonl','w',encoding='utf-8') as f:
    for i,m in enumerate(meta): f.write(json.dumps({"index":i,**m})+"\n")

inv=sum(1 for e in syn for tc in (e['messages'][-1].get('tool_calls') or [])
        if tc['function']['name'] not in APPROVED)
mlt=sum(1 for e in syn if len(e['messages'][-1].get('tool_calls') or [])>1)
import collections
cost=tin/1e6+tout/1e6*5
print(f"\nN1: {len(syn)} synthetic, {len(set(m['article'] for m in meta))}/11 articles")
print("per-article:",dict(collections.Counter(m['article'] for m in meta)))
print(f"invented-name tool_calls: {inv} (must 0) | multi-tool msgs: {mlt} (must 0)")
print(f"rerolls: {rerolls or 'none'}")
print(f"fails: {fails or 'none'}")
print(f"tokens in={tin} out={tout} est_cost=${cost:.3f}")
EOF
