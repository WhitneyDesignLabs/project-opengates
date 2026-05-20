#!/bin/bash
# Phase 3.2 step 1b N1: syntax-check edited module, size seed corpus,
# run --self-check --use-haiku, and flag v1-clean -> v2-fabricated flips.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
export ANTHROPIC_API_KEY="$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2

echo "== syntax/import check =="
python3 -c "import ast,sys; ast.parse(open('wrap_up_classify.py').read()); print('AST OK')" || exit 3
python3 -c "import wrap_up_classify as w; print('import OK; classes=',w.WRAP_UP_CLASSES)" || exit 3

echo "== locate + size seed corpus =="
python3 -c "
import wrap_up_classify as w, json
p=w.SEED_CORPUS
print('SEED_CORPUS=',p,'exists=',p.exists())
d=json.loads(p.read_text())
convs=d.get('conversations',d) if isinstance(d,dict) else d
print('seed conversations =',len(convs))
from collections import Counter
print('seed human_label dist =',dict(Counter(c.get('human_label') or c.get('wrap_up_class') for c in convs)))
"

echo "== deterministic-only pass on seed (no API): old-clean cases now -> ? =="
python3 -c "
import wrap_up_classify as w, json
from collections import Counter
d=json.loads(w.SEED_CORPUS.read_text()); convs=d.get('conversations',d) if isinstance(d,dict) else d
det=Counter()
for c in convs:
    n=w.normalize_conversation(c)
    r=w.classify_deterministic(n['wrap_up_text'],n['tool_calls'],n['tool_results'])
    det[r.label]+=1
print('v2 deterministic label dist (seed):',dict(det))
print('  -> expect only pseudo-prose/fabricated/null (NO clean, NO uncertain)')
"

echo "== full self-check WITH Haiku (seed is small; few API calls) =="
python3 wrap_up_classify.py --self-check --use-haiku 2>&1 | tail -40
