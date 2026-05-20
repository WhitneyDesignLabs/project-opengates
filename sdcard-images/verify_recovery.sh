#!/bin/bash
# Phase 3.1.3 recovery verify. Poll until each Pi reaches session>=3
# (=> persona_01 AND persona_02 sessions completed) with no
# "persona not found" since the 20:26 relaunch. ~16 min cap.
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $HOME/.ssh/evobot_ed25519"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"
probe() {
  # $1 = ssh cmd ; prints "sess|persona|errs|consec|pnf"
  $1 'st=$(cat ~/.overnight-capture.status 2>/dev/null);
      s=$(echo "$st" | sed -nE "s/session=([0-9]+).*/\1/p");
      p=$(echo "$st" | sed -nE "s/.*persona=([a-z0-9_]+).*/\1/p");
      e=$(echo "$st" | sed -nE "s/.*errors=([0-9]+).*/\1/p");
      c=$(echo "$st" | sed -nE "s/.*consecutive_errors=([0-9]+).*/\1/p");
      pnf=$(awk "/overnight capture START/{n=NR} END{print n}" ~/overnight-capture.log >/dev/null 2>&1;
            tail -n 120 ~/overnight-capture.log 2>/dev/null | grep -c "persona not found");
      echo "${s:-0}|${p:-?}|${e:-0}|${c:-0}|${pnf:-0}"' 2>/dev/null
}
i=0
while [ $i -lt 16 ]; do
  E=$(probe "$EVO"); A=$(probe "$P2"); B=$(probe "$P3")
  echo "[$i] evo=$E pi02=$A pi03=$B"
  se=${E%%|*}; sa=${A%%|*}; sb=${B%%|*}
  if [ "${se:-0}" -ge 3 ] && [ "${sa:-0}" -ge 3 ] && [ "${sb:-0}" -ge 3 ]; then
    echo "ALL_PAST_PERSONA01"; break
  fi
  i=$((i+1)); sleep 60
done
echo "=== final (fields: session|persona|errors|consec|persona_not_found_count) ==="
echo "EvoBot: $(probe "$EVO")"
echo "pi02:   $(probe "$P2")"
echo "pi03:   $(probe "$P3")"
