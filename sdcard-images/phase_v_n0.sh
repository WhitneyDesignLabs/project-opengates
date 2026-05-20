#!/bin/bash
# Phase 3.3.1c N0: re-tokenize captured + v1 synthetic with the new
# (IDENTITY-bearing) SOUL-LOCAL.md as system message. Backups preserved.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, shutil
TD='fork/lora/training-data'
sl=open(f'{TD}/constitution/SOUL-LOCAL.md',encoding='utf-8').read()
soul=("\n".join(l for l in sl.splitlines() if not l.startswith("# "))).strip()
print(f"new SOUL-LOCAL system msg: {len(soul)} chars / {len(soul.encode())} bytes, "
      f"{len(soul.splitlines())} lines; IDENTITY present: {'WireClaw-Agent' in soul}")

for fn in ('wireclaw-v1-captured.jsonl','wireclaw-v1-synthetic.jsonl'):
    src=f'{TD}/{fn}'
    before=len(open(src,'rb').read())
    rows=[json.loads(l) for l in open(src,encoding='utf-8')]
    shutil.copy(src, src+'.v1-pre-identity.bak')
    n=0
    for ex in rows:
        for msg in ex['messages']:
            if msg['role']=='system':
                msg['content']=soul; n+=1; break
    with open(src,'w',encoding='utf-8') as f:
        for ex in rows: f.write(json.dumps(ex,ensure_ascii=False)+"\n")
    after=len(open(src,'rb').read())
    # verify ALL system messages now equal soul
    ok=all(next(m for m in json.loads(l)['messages'] if m['role']=='system')['content']==soul
           for l in open(src,encoding='utf-8'))
    print(f"{fn}: {len(rows)} rows, sys-msg replaced in {n}; bytes {before} -> {after}; "
          f"all-system==SOUL-LOCAL: {ok}; backup {fn}.v1-pre-identity.bak")
EOF
