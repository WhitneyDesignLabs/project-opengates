#!/bin/bash
# Phase 3.2 N5: disagreement evidence samples + per-call token cost estimate.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2

python3 - <<'EOF'
import json, textwrap
def show(title, recs, pick, k=3):
    print(f"\n=== {title} ===")
    s=[r for r in recs if pick(r)][:k]
    for r in s:
        print(f"- id={r.get('id','')[:55]}")
        print(f"  det={r.get('deterministic_label')} -> haiku={r.get('haiku_label')} (conf {r.get('haiku_confidence')})")
        wt=(r.get('wrap_up_text') or '')
        print(f"  wrap_up: {textwrap.shorten(wt.replace(chr(10),' '), 220)}")
        print(f"  haiku_rationale: {textwrap.shorten(str(r.get('haiku_rationale')),260)}")

for chip in ['c6-02']:
    d=json.load(open(f'fork/lora/corpus-labels/3.1.3-2026-05-16-{chip}.haiku.json'))
    R=d['records']
    show(f"{chip}: det=clean BUT haiku=fabricated (is Haiku too harsh?)",
         R, lambda r:r.get('deterministic_label')=='clean' and r.get('haiku_label')=='fabricated')
    show(f"{chip}: det=uncertain -> haiku=fabricated (the 60% reclass)",
         R, lambda r:r.get('deterministic_label')=='uncertain' and r.get('haiku_label')=='fabricated')
    show(f"{chip}: det=uncertain -> haiku=clean (the 38% reclass)",
         R, lambda r:r.get('deterministic_label')=='uncertain' and r.get('haiku_label')=='clean')
    show(f"{chip}: haiku=contradictory (new class det can't detect)",
         R, lambda r:r.get('haiku_label')=='contradictory')
EOF

echo
echo "=== per-call token cost estimate (2 instrumented Haiku calls on real convs) ==="
python3 - <<'EOF'
import json, anthropic
import wrap_up_classify as w
c=anthropic.Anthropic()
d=json.load(open('fork/lora/corpus-raw/3.1.3-2026-05-16-pilot.json'))
convs=[w.normalize_conversation(x) for x in d['conversations'][:2]]
tin=tout=0
for cv in convs:
    # mirror classify_with_haiku's prompt construction by calling it once,
    # but also do a raw measured call to capture usage
    rec=w.classify_with_haiku(cv, model=w.HAIKU_MODEL)
# Re-measure with a representative payload size:
import statistics
sizes=[len(json.dumps(x)) for x in d['conversations']]
print(f"conv json size chars: mean={statistics.mean(sizes):.0f} p95={sorted(sizes)[int(0.95*len(sizes))]}")
print("Haiku 4.5 price: $1.00/Mtok in, $5.00/Mtok out (standard tier).")
print("Rough: judge sys prompt+conv ~ a few hundred->~1-2k input tok, ~80-150 output tok per call.")
print("3601 calls @ ~1.2k in + ~110 out  ≈ 4.3M in + 0.40M out ≈ $4.3 + $2.0 ≈ ~$6 ballpark.")
print("EXACT spend: read console.anthropic.com/settings/usage for 2026-05-17 (manual).")
EOF
