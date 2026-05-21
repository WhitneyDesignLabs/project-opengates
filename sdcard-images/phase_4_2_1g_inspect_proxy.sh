#!/bin/bash
# Run on azza. Show model + src for 3 most recent proxy JSONs.
cd /home/azza/wireclaw-corpus/ollama-raw/2026-05-20/ || exit 1
for f in $(ls -t | head -5); do
  echo "=== $f ==="
  python3 -c "
import json
d = json.load(open('$f'))
print('model:    ', d.get('req', {}).get('model', '?'))
print('client_ip:', d.get('client_ip', d.get('client', '?')))
msgs = d.get('req', {}).get('messages', [])
last = msgs[-1].get('content', '') if msgs else ''
print('last_msg: ', last[:140].replace(chr(10), ' '))
resp = d.get('resp', {}) if isinstance(d.get('resp'), dict) else {}
if 'message' in resp:
    rc = resp.get('message', {}).get('content', '')[:200]
    print('reply:    ', rc.replace(chr(10), ' '))
"
done
