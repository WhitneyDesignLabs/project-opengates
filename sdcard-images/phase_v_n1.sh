#!/bin/bash
# Phase 3.3.1c N1: 3 targeted synthetic batches -> wireclaw-v1-synthetic-v2.jsonl
#  A identity(15,no-tool)  B refusal+citation(40: art3x20,4x6,12x6,15x4,19x4)
#  C memory-chain first-step(35, single file_read only)
set -u
SEC=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SEC" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import anthropic, json, re, time
TD='fork/lora/training-data'
soul=open(f'{TD}/constitution/SOUL.md',encoding='utf-8').read()
sl=open(f'{TD}/constitution/SOUL-LOCAL.md',encoding='utf-8').read()
SYS=("\n".join(l for l in sl.splitlines() if not l.startswith("# "))).strip()
APPROVED={"led_set","gpio_write","gpio_read","temperature_read","device_info",
"device_list","device_register","sensor_read","actuator_set","file_read",
"file_write","rule_create","rule_delete","rule_enable","rule_list",
"serial_send","nats_publish","remote_chat","chain_create"}
client=anthropic.Anthropic(); tin=tout=0; rerolls=[]
def call(prompt):
    global tin,tout
    r=client.messages.create(model="claude-haiku-4-5-20251001",
        max_tokens=4500, messages=[{"role":"user","content":prompt}])
    tin+=r.usage.input_tokens; tout+=r.usage.output_tokens
    t="".join(b.text for b in r.content if getattr(b,'type',None)=='text').strip()
    m=re.search(r'\[.*\]',t,re.DOTALL)
    return json.loads(m.group(0)) if m else None

# article blocks
hdr=re.compile(r'^### Article (\d+):\s*(.*)$'); blocks={}; titles={}; cur=None; buf=[]
for ln in soul.splitlines():
    mm=hdr.match(ln)
    if mm:
        if cur is not None: blocks[cur]="\n".join(buf).strip()
        cur=mm.group(1); titles[cur]=mm.group(2).strip(); buf=[ln]
    elif cur is not None:
        if ln.startswith('## ') and not ln.startswith('### '):
            blocks[cur]="\n".join(buf).strip(); cur=None; buf=[]
        else: buf.append(ln)
if cur is not None: blocks[cur]="\n".join(buf).strip()

syn=[]; meta=[]
def add(ex, source, want_tools):
    am={"role":"assistant","content":ex.get("assistant_content","")}
    tcs=ex.get("tool_calls") or []
    if want_tools=="forbid" and tcs: return False
    if tcs:
        if len(tcs)!=1: return False
        tc=tcs[0]; nm=tc.get("name") or (tc.get("function") or {}).get("name")
        if nm not in APPROVED: return False
        if source.startswith("synthetic-v2-batchC") and nm!="file_read": return False
        am["tool_calls"]=[{"type":"function","function":{"name":nm,
            "arguments":json.dumps(tc.get("arguments",{}))}}]
    elif source.startswith("synthetic-v2-batchC"):
        return False  # batch C MUST have the file_read call
    if not ex.get("user"): return False
    syn.append({"messages":[{"role":"system","content":SYS},
        {"role":"user","content":ex["user"]},am]})
    meta.append({"source":source}); return True

# ---- Batch A: identity (15, no tools) ----
A='''Generate 15 training examples where the user asks WireClaw-Agent about its identity, origins, capabilities, or governing principles. Assistant responses MUST: identify as "WireClaw-Agent" (never "device agent","AI assistant","Llama","ChatGPT"); acknowledge Project Opengates and Whitney Design Labs as creators when relevant; reference the SOUL constitution when ethics/principles asked; be conversational with NO tool_calls. Vary phrasings: "who are you","what are you","what model are you","who made you","what's your name","tell me about yourself","are you llama","are you ChatGPT","what can you do", etc. Output ONLY a JSON array of 15 {"user","assistant_content"} objects.'''
for attempt in range(3):
    arr=call(A) or []
    good=[e for e in arr if e.get("user") and "WireClaw-Agent" in (e.get("assistant_content") or "")]
    if len(good)>=12: break
    rerolls.append(("A",attempt,f"only {len(good)} valid identity"))
for e in good: add(e,"synthetic-v2-batchA-identity","forbid")

# ---- Batch B: refusal + correct citation ----
PLAN=[("3",20),("4",6),("12",6),("15",4),("19",4)]
bad3=re.compile(r'Article\s+\d+\.\d+\.\d+')  # ban 3-level fabricated subarticles
for art,N in PLAN:
    atext=blocks.get(art,""); title=titles.get(art,"")
    P=f'''Generate {N} training examples where WireClaw-Agent refuses a user request that violates Article {art}: {title}.

Article {art} text:
{atext}

Each example: user makes a request triggering this article's prohibition; assistant refuses clearly and cites "Article {art}" BY NUMBER (forms: "Per Article {art}...", "Article {art} — {title} — applies here:..."). Cite ONLY Article {art} (optionally "Article {art}.{{M}}" if {art} has real numbered sub-sections in the text above). NEVER invent sub-articles like "Article 9.3.2". Offer a safe alternative if appropriate. NO tool_calls. Vary scenarios (direct, indirect, borderline). Output ONLY a JSON array of {N} {{"user","assistant_content"}} objects.'''
    for attempt in range(3):
        arr=call(P) or []
        ok=[]
        for e in arr:
            c=e.get("assistant_content") or ""
            if not e.get("user") or not c: continue
            if bad3.search(c): continue                       # fabricated subarticle
            if f"Article {art}" not in c: continue            # must cite target
            ok.append(e)
        if len(ok)>=max(3,int(N*0.7)): break
        rerolls.append((f"B-art{art}",attempt,f"only {len(ok)}/{N} valid"))
    for e in ok[:N]: add(e,f"synthetic-v2-batchB-art{art}","forbid")
    time.sleep(0.3)

# ---- Batch C: memory-chain first-step (35, single file_read only) ----
C='''Generate 35 training examples teaching WireClaw-Agent to read memory FIRST when the user references stored preferences/notes. Pattern: user references stored state -> assistant makes a SINGLE tool_call file_read with arguments {"path":"/memory.txt"} AND a brief content acknowledgment (e.g. "Let me check your memory."). The assistant must NOT guess values and must NOT call led_set/gpio_write/any other tool — ONLY file_read. Vary user messages: "set LED to my favorite color","what's my dog's name","use that color again","remind me what I asked yesterday","tell me my note","what did I say to remember","do that thing I asked about", etc. Output ONLY a JSON array of 35 objects: {"user":"...","assistant_content":"...","tool_calls":[{"name":"file_read","arguments":{"path":"/memory.txt"}}]}'''
for attempt in range(3):
    arr=call(C) or []
    ok=[e for e in arr if e.get("user") and (e.get("tool_calls") or [])
        and ((e["tool_calls"][0].get("name") or (e["tool_calls"][0].get("function") or {}).get("name"))=="file_read")
        and len(e["tool_calls"])==1]
    if len(ok)>=25: break
    rerolls.append(("C",attempt,f"only {len(ok)} valid memory-chain"))
for e in ok[:35]: add(e,"synthetic-v2-batchC-memchain","require")

with open(f'{TD}/wireclaw-v1-synthetic-v2.jsonl','w',encoding='utf-8') as f:
    for e in syn: f.write(json.dumps(e,ensure_ascii=False)+"\n")
with open(f'{TD}/wireclaw-v1-synthetic-v2.meta.jsonl','w',encoding='utf-8') as f:
    for i,m in enumerate(meta): f.write(json.dumps({"index":i,**m})+"\n")

import collections
bysrc=collections.Counter(m['source'].rsplit('-',1)[0] if 'art' not in m['source']
                          else m['source'] for m in meta)
inv=sum(1 for e in syn for tc in (e['messages'][-1].get('tool_calls') or [])
        if tc['function']['name'] not in APPROVED)
cmis=sum(1 for e,m in zip(syn,meta) if m['source'].startswith('synthetic-v2-batchC')
         and (e['messages'][-1].get('tool_calls') or [{}])[0].get('function',{}).get('name')!='file_read')
sysok=all(e['messages'][0]['content']==SYS for e in syn)
print(f"\nN1: {len(syn)} v2 synthetic")
print("by batch:",dict(bysrc))
print(f"invented tool names: {inv} (0) | batchC non-file_read: {cmis} (0) | all-system==SOUL-LOCAL: {sysok}")
print(f"rerolls: {rerolls or 'none'}")
print(f"tokens in={tin} out={tout} est_cost=${tin/1e6+tout/1e6*5:.3f}")
EOF
