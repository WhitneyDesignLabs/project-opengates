#!/bin/bash
# Phase 4.1.1 §1.2b validation: run the PATCHED persona_runner.py live on
# c6-02 via pi02 for two objective-probe personas (~20 turns), pull the
# JSONL, and measure prompt->reply on-topic correspondence. Pre-fix the
# scrambled corpus scored ~14% temp-on-topic; the fix should put this at
# (near) 100% with msgs_collected>1 proving multi-message settle works.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
SCP="scp -q -o BatchMode=yes -o ConnectTimeout=12 -i $K"
DEST=/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/validate-4.1.1
mkdir -p "$DEST"

$SSH scott@192.168.1.17 'bash -s' <<'REMOTE'
set -u
set -a; . ~/.wireclaw-secrets.env; set +a
PY=~/phase31-venv/bin/python
R=~/wireclaw-phase31/bench/fork/lora/persona_runner.py
SESS=~/.telethon-pi02.session
BOT=wdl_c6_02_bot
for P in persona_01_basic persona_07_sensor_telemetry; do
  echo "=== running $P against $BOT ==="
  "$PY" "$R" --persona "$P" --bot-username "$BOT" \
      --session-file "$SESS" \
      --out /tmp/validate_4_1_1_$P.jsonl 2>&1 | tail -n 14
done
echo "=== produced ==="
wc -l /tmp/validate_4_1_1_*.jsonl
REMOTE

echo "=== pulling ==="
$SCP 'scott@192.168.1.17:/tmp/validate_4_1_1_*.jsonl' "$DEST/" 2>/dev/null
ls -la "$DEST"

python3 - "$DEST" <<'PY'
import json, re, sys, glob, os
d = sys.argv[1]
TEMPQ=re.compile(r'\b(temperature|temp)\b',re.I); TEMPA=re.compile(r'(degree|celsius|°c|\btemp)',re.I)
LEDQ=re.compile(r'\bled\b',re.I); LEDA=re.compile(r'\bled\b',re.I)
IPQ=re.compile(r'\bip address\b',re.I); IPA=re.compile(r'(\d+\.\d+\.\d+\.\d+|ip address)',re.I)
def k(p):
    if TEMPQ.search(p): return 'temp'
    if IPQ.search(p): return 'ip'
    if LEDQ.search(p): return 'led'
def m(kk,a):
    return bool({'temp':TEMPA,'led':LEDA,'ip':IPA}[kk].search(a)) if kk else False
rows=[]
for f in sorted(glob.glob(os.path.join(d,'validate_4_1_1_*.jsonl'))):
    for ln in open(f,encoding='utf-8'):
        ln=ln.strip()
        if ln: rows.append(json.loads(ln))
print(f"total turns: {len(rows)}")
tot={}; hit={}
mc=[r.get('msgs_collected') for r in rows if 'msgs_collected' in r]
for r in rows:
    kk=k(r.get('prompt_text',''))
    if not kk: continue
    tot[kk]=tot.get(kk,0)+1
    if m(kk, r.get('reply_text') or ''): hit[kk]=hit.get(kk,0)+1
print("objective on-topic (target ~100%, was ~14% pre-fix):")
for kk in tot: print(f"  {kk}: {hit.get(kk,0)}/{tot[kk]} = {100*hit.get(kk,0)/tot[kk]:.0f}%")
if mc: print(f"msgs_collected: min={min(mc)} max={max(mc)} avg={sum(mc)/len(mc):.1f}  (>1 avg confirms multi-message settle is engaging)")
to=sum(1 for r in rows if r.get('reply_timed_out'))
print(f"timeouts: {to}/{len(rows)}")
print("\nsample pairs:")
for r in rows[:8]:
    print(f"  q={r.get('prompt_text','')[:48]!r} -> a={(r.get('reply_text') or '')[:80]!r}")
PY
