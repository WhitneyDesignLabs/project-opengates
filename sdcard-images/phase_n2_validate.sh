#!/bin/bash
# Phase 3.2 N2 pre-flight: 3-conversation end-to-end Haiku validation (~$0.01)
# to confirm the .haiku.json schema before the 3601-call run.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
val=$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)
export ANTHROPIC_API_KEY="$val"
BENCH="/mnt/c/Users/homet/Documents/WireClaw/bench"
cd "$BENCH" || exit 2

mkdir -p /tmp/n2val
python3 -c "
import json
d=json.load(open('fork/lora/corpus-raw/3.1.3-2026-05-16-pilot.json'))
slice={'session_id':'n2-validate','conversations':d['conversations'][:3]}
json.dump(slice, open('/tmp/n2val/mini.json','w'))
print('mini corpus: 3 conversations')
"
python3 wrap_up_classify.py --use-haiku \
    --corpus /tmp/n2val/mini.json \
    --out /tmp/n2val/mini.haiku.json 2>&1

echo "== schema check =="
python3 -c "
import json
o=json.load(open('/tmp/n2val/mini.haiku.json'))
print('top keys:', sorted(o.keys()))
print('summary:', o['summary'])
r=o['records'][0]
for k in ('id','deterministic_label','haiku_label','final_label','haiku_rationale'):
    print(f'  {k} = {str(r.get(k))[:90]}')
print('records:', len(o['records']))
"
