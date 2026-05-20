#!/bin/bash
# Phase 3.2 N2 pre-flight: 25-conversation real Haiku run (~$0.02) to confirm
# sustained credit AFTER the billing reup, before the 3601-call run.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
val=$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)
export ANTHROPIC_API_KEY="$val"
BENCH="/mnt/c/Users/homet/Documents/WireClaw/bench"
cd "$BENCH" || exit 2
mkdir -p /tmp/n2probe
python3 -c "
import json
d=json.load(open('fork/lora/corpus-raw/3.1.3-2026-05-16-pilot.json'))
json.dump({'session_id':'n2-probe25','conversations':d['conversations'][:25]},
          open('/tmp/n2probe/p25.json','w'))
print('probe corpus: 25 conversations')
"
t0=$(date +%s)
python3 wrap_up_classify.py --use-haiku \
    --corpus /tmp/n2probe/p25.json \
    --out /tmp/n2probe/p25.haiku.json 2>&1
t1=$(date +%s)
echo "wall: $((t1-t0))s for 25 convs"
python3 -c "
import json,collections
o=json.load(open('/tmp/n2probe/p25.haiku.json'))
recs=o['records']
nn=sum(1 for r in recs if r.get('haiku_label') is not None)
diff=sum(1 for r in recs if r.get('final_label')!=r.get('deterministic_label'))
errs=[r.get('haiku_rationale') for r in recs if r.get('haiku_label') is None]
print(f'records={len(recs)} haiku_non_null={nn} final!=det={diff}')
print('haiku_label dist:', dict(collections.Counter(r.get(\"haiku_label\") for r in recs)))
if errs:
    print('SAMPLE ERROR rationale:', str(errs[0])[:200])
    print('VERDICT: FAIL (haiku still erroring)')
elif nn==len(recs):
    print('VERDICT: PASS (all 25 got real Haiku labels) -> safe to launch 3601')
else:
    print('VERDICT: PARTIAL -- inspect before full run')
"
