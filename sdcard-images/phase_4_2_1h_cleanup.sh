#!/bin/bash
# H.3 — pre-launch cleanup. Clear STOP_FLAG + status files on each Pi;
# clear rules on each chip.
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"

echo "=== H.3a Pi-side cleanup (STOP_FLAG + status files) ==="
for spec in evobot:192.168.1.51 pi02:192.168.1.17 pi03:192.168.1.44; do
  name=${spec%%:*}; ip=${spec##*:}
  echo "[$name $ip]"
  $SSH "scott@$ip" "
    rm -f ~/STOP_FLAG ~/.stop-overnight-capture ~/.overnight-capture.status ~/.overnight-capture.status.final
    echo 'remaining flag/status files:'
    ls ~/STOP_FLAG ~/.stop-overnight-capture ~/.overnight-capture.status ~/.overnight-capture.status.final 2>&1 | grep -v 'No such file' | head -3 || echo '  (none)'
    # Pre-flight: confirm no overnight_capture or persona_runner is already running
    PR=\$(pgrep -af '[o]vernight_capture.sh' | head -3)
    PE=\$(pgrep -af '[p]ersona_runner.py' | head -3)
    [ -n \"\$PR\" ] && echo \"WARN already running: \$PR\"
    [ -n \"\$PE\" ] && echo \"WARN already running: \$PE\"
    [ -z \"\$PR\" ] && [ -z \"\$PE\" ] && echo '  no stale processes'
  "
done

echo
echo "=== H.3b chip-side rule clears ==="
for spec in c6-02:192.168.1.15 c6-03:192.168.1.47 c6-01:192.168.1.19; do
  name=${spec%%:*}; ip=${spec##*:}
  printf "[$name $ip] "
  R=$(curl -sS -m 5 -X POST "http://$ip/api/rules/delete" -H "Content-Type: application/json" -d '{"id":"all"}' 2>&1)
  echo "$R"
  # verify
  V=$(curl -sS -m 5 "http://$ip/api/rules" 2>&1)
  echo "  rules now: $V"
done
echo "done."
