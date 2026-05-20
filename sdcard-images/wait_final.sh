#!/bin/bash
# Poll the 3 Pis until each has written ~/.overnight-capture.status.final
# (loop drains current in-flight session after the stop flag, then writes .final).
K=~/.ssh/evobot_ed25519
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"
i=0
while [ $i -lt 30 ]; do
  fe=$($EVO 'test -f ~/.overnight-capture.status.final && echo Y || echo N' 2>/dev/null)
  f2=$($P2 'test -f ~/.overnight-capture.status.final && echo Y || echo N' 2>/dev/null)
  f3=$($P3 'test -f ~/.overnight-capture.status.final && echo Y || echo N' 2>/dev/null)
  se=$($EVO 'cat ~/.overnight-capture.status 2>/dev/null | tr "\n" " "' 2>/dev/null)
  s2=$($P2 'cat ~/.overnight-capture.status 2>/dev/null | tr "\n" " "' 2>/dev/null)
  s3=$($P3 'cat ~/.overnight-capture.status 2>/dev/null | tr "\n" " "' 2>/dev/null)
  echo "[$i] final evo=$fe pi02=$f2 pi03=$f3 | evo{$se} pi02{$s2} pi03{$s3}"
  if [ "$fe" = Y ] && [ "$f2" = Y ] && [ "$f3" = Y ]; then echo ALL_FINAL; break; fi
  i=$((i+1)); sleep 45
done
echo "=== .status.final dumps ==="
echo "--- EvoBot ---"; $EVO 'cat ~/.overnight-capture.status.final 2>/dev/null || echo MISSING'
echo "--- pi02 ---";   $P2  'cat ~/.overnight-capture.status.final 2>/dev/null || echo MISSING'
echo "--- pi03 ---";   $P3  'cat ~/.overnight-capture.status.final 2>/dev/null || echo MISSING'
