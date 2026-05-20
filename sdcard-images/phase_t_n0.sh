#!/bin/bash
# Phase 3.3.1 N0: regenerate synthetic examples with the REAL WireClaw toolset
# enforced; reroll articles that emit invented tool names (max 2); re-split.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
TD=fork/lora/training-data

# 1. preserve prior invented-tools synthetic
[ -f "$TD/wireclaw-v1-synthetic.jsonl" ] && \
  cp -v "$TD/wireclaw-v1-synthetic.jsonl" "$TD/wireclaw-v1-synthetic.invented-tools.jsonl"
[ -f "$TD/wireclaw-v1-synthetic.meta.jsonl" ] && \
  cp "$TD/wireclaw-v1-synthetic.meta.jsonl" "$TD/wireclaw-v1-synthetic.invented-tools.meta.jsonl"

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

hdr=re.compile(r'^### Article (\d+):\s*(.*)$')
blocks={}; cur=None; buf=[]
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

TOOLS_BLOCK='''THE AGENT'S TOOLSET IS FIXED. Use ONLY these tools:
- led_set(r, g, b) — set RGB LED color
- gpio_write(pin, value) — set GPIO pin high/low
- gpio_read(pin) — read GPIO pin state
- temperature_read() or temperature_read(sensor_name) — read temp
- device_info() — get IP/heap/uptime/chip info
- device_list() — list registered devices
- device_register(name, type, pin) — register a new actuator/sensor
- sensor_read(name) or sensor_read(names=[...]) — read sensor value(s)
- actuator_set(name, value, duration?) — set named actuator state
- file_read(path) — read file (typically /memory.txt)
- file_write(path, content) — write file
- rule_create(...) — create automation rule
- rule_delete(rule_name) or rule_delete(rule_id) — remove rule
- rule_enable(rule_name) — enable a rule
- rule_list() — list active rules
- serial_send(text) — send text over local UART
- nats_publish(subject, payload) — remote pub (L3+ per Article 15)
- remote_chat(agent, message) — remote agent chat (L3+ per Article 15)
- chain_create(...) — multi-step sequence

DO NOT invent new tool names. If a scenario would need a tool that
doesn't exist (e.g., "set the thermostat"), have the assistant either
(a) decline because the tool isn't available, or (b) re-cast the
request into available tools (e.g., "I don't have a thermostat tool,
but I can control a GPIO-connected relay if you register one with
device_register").'''

def GEN(article):
    return f'''You are generating training data for WireClaw-Agent, a constitutional AI agent running on an ESP32-C6 microcontroller. The agent controls GPIO pins, an RGB LED, sensors, automation rules, and a small memory file (/memory.txt). It governs itself by SOUL.md.

{TOOLS_BLOCK}

Generate 8 diverse training examples exercising this article's principle:

{article}

Diversity guidance:
- Mix clear cases with borderline cases
- Some examples should show the article informing HOW to do something (not just refusals)
- Some should include tool_calls (with REAL tool names only); some shouldn't need any
- User messages should sound like real Telegram messages — terse, conversational, or technical
- Assistant responses should demonstrate the principle through behavior, not by quoting the article text
- Refusals MUST cite the article BY NUMBER ("per Article 3...")
- Most examples should NOT be refusals — show the principle in positive action

Output as a JSON array of 8 objects:
[{{"user":"<user message>","assistant_content":"<wrap-up text>","tool_calls":[{{"name":"<real tool name>","arguments":{{}}}}]}}]
tool_calls optional, omit if no tools needed. Return ONLY the JSON array, no preamble.'''

client=anthropic.Anthropic()
syn=[]; meta=[]; tin=tout=0; reroll_log=[]; fails=[]
for num,name in ARTS:
    art=blocks.get(num)
    if not art: fails.append((num,"no article text")); continue
    accepted=None
    for attempt in range(3):  # initial + max 2 rerolls
        try:
            r=client.messages.create(model="claude-haiku-4-5-20251001",
                max_tokens=4000, messages=[{"role":"user","content":GEN(art)}])
        except Exception as e:
            m=str(e)
            if '400' in m or 'credit' in m.lower() or '401' in m:
                print("CREDIT/AUTH error -> abort:",m[:160]); raise SystemExit(2)
            fails.append((num,f"api:{m[:100]}")); break
        tin+=r.usage.input_tokens; tout+=r.usage.output_tokens
        txt="".join(b.text for b in r.content if getattr(b,'type',None)=='text').strip()
        mm=re.search(r'\[.*\]',txt,re.DOTALL)
        if not mm: reroll_log.append((num,attempt,"no JSON")); continue
        try: arr=json.loads(mm.group(0))
        except Exception as e: reroll_log.append((num,attempt,f"bad JSON {e}")); continue
        invented=set()
        for ex in arr:
            for tc in (ex.get("tool_calls") or []):
                nm=tc.get("name") or (tc.get("function") or {}).get("name")
                if nm and nm not in APPROVED: invented.add(nm)
        if invented:
            reroll_log.append((num,attempt,f"invented {sorted(invented)}")); continue
        accepted=arr; break
    if accepted is None:
        fails.append((num,"still invented after 2 rerolls")); continue
    kept=0
    for ex in accepted:
        if not isinstance(ex,dict) or 'user' not in ex or 'assistant_content' not in ex: continue
        am={"role":"assistant","content":ex["assistant_content"]}
        conv=[]; ok=True
        for tc in (ex.get("tool_calls") or []):
            nm=tc.get("name") or (tc.get("function") or {}).get("name")
            if not nm or nm not in APPROVED: ok=False; break
            conv.append({"type":"function","function":{"name":nm,
                         "arguments":json.dumps(tc.get("arguments",{}))}})
        if ok and conv: am["tool_calls"]=conv
        elif not ok: continue
        syn.append({"messages":[{"role":"system","content":soul_local},
                                {"role":"user","content":ex["user"]},am]})
        meta.append({"source":f"synthetic-art{num}","article":num}); kept+=1
    print(f"art{num} ({name}): kept {kept}")
    time.sleep(0.5)

with open(f'{TD}/wireclaw-v1-synthetic.jsonl','w',encoding='utf-8') as f:
    for e in syn: f.write(json.dumps(e,ensure_ascii=False)+"\n")
with open(f'{TD}/wireclaw-v1-synthetic.meta.jsonl','w',encoding='utf-8') as f:
    for i,m in enumerate(meta): f.write(json.dumps({"index":i,**m})+"\n")

# post-validate: ZERO invented names anywhere
bad=0
for e in syn:
    for tc in (e['messages'][-1].get('tool_calls') or []):
        if tc['function']['name'] not in APPROVED: bad+=1
import collections
cost=tin/1e6*1.0+tout/1e6*5.0
print(f"\nN0: {len(syn)} synthetic across {len(set(m['article'] for m in meta))}/11 articles")
print("per-article:",dict(collections.Counter(m['article'] for m in meta)))
print(f"INVENTED-NAME tool_calls remaining: {bad} (must be 0)")
print(f"rerolls: {reroll_log if reroll_log else 'none'}")
print(f"fails: {fails if fails else 'none'}")
print(f"tokens in={tin} out={tout} est_cost=${cost:.3f}")
EOF
