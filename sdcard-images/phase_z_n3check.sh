#!/bin/bash
# Pre-launch verify: pi02/pi03 overnight_capture.sh per-Pi config correct,
# telethon session present, no loop already running, last-run .final.
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$S scott@192.168.1.17"
P3="$S scott@192.168.1.44"
chk() {  # $1 pi-ssh  $2 label  $3 expect-bot  $4 expect-chipip
  echo "===== $2 (expect bot=$3 chip=$4) ====="
  $1 "OC=~/wireclaw-phase31/bench/fork/lora/overnight_capture.sh
      echo '-- per-Pi config in overnight_capture.sh --'
      grep -nE '^BOT_USERNAME=|^SESSION_FILE=|^RULE_PURGE_URL=' \"\$OC\" 2>/dev/null || echo 'GREP_FAIL'
      echo -n 'telethon session: '; ls ~/.telethon-*.session 2>/dev/null | tr '\n' ' '; echo
      echo -n 'loop already running? '; pgrep -af overnight_capture.sh >/dev/null 2>&1 && (echo YES; pgrep -af overnight_capture.sh) || echo no
      echo -n 'stale stop-flag: '; [ -f ~/.stop-overnight-capture ] && echo PRESENT || echo absent
      echo '-- last run .status.final --'; cat ~/.overnight-capture.status.final 2>/dev/null || echo '(none)'
      echo -n 'persona modules: '; ls ~/wireclaw-phase31/bench/fork/lora/personas/persona_0[1-7]_*.py 2>/dev/null | wc -l" 2>&1
}
chk "$P2" "pi02->c6-02" wdl_c6_02_bot 192.168.1.15
chk "$P3" "pi03->c6-03" wdl_c6_03_bot 192.168.1.47
