#!/bin/bash
set -u
CL="/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels"
python3 - "$CL" <<'PY'
import sys, json
CL=sys.argv[1]
o=json.load(open(f"{CL}/3.1.3-2026-05-16-pilot.haiku.json"))
r=o['records'][0]
print("FULL haiku_rationale (first record):")
print(" ", r.get('haiku_rationale'))
print()
print("sample record final vs deterministic vs haiku:")
for k in ('id','deterministic_label','haiku_label','final_label'):
    print(f"  {k} = {r.get(k)}")
# Confirm final == deterministic everywhere (no real haiku influence)
import collections
mism=sum(1 for x in o['records'] if x.get('final_label')!=x.get('deterministic_label'))
print(f"\npilot: records where final != deterministic = {mism} (expect 0 = haiku had no effect)")
PY
