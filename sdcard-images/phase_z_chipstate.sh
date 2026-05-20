#!/bin/bash
# Re-probe c6-02/c6-03 live state from paired Pis: up? live model? uptime?
# (handleGetConfig returns the in-RAM boot value -> tells us if reboot applied)
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$S scott@192.168.1.17"
P3="$S scott@192.168.1.44"
chk() {  # $1 pi-ssh  $2 ip  $3 label
  echo "===== $3 ($2) ====="
  $1 "echo -n 'ping: '; ping -c2 -W2 $2 >/dev/null 2>&1 && echo UP || echo DOWN
      sc=\$(curl -s -m8 -o /tmp/st.txt -w '%{http_code}' http://$2/api/status 2>/dev/null); echo \"/api/status HTTP=\$sc\"
      [ \"\$sc\" = 200 ] && python3 -c 'import json;d=json.load(open(\"/tmp/st.txt\"));print(\"  status model=\"+str(d.get(\"model\"))+\" uptime=\"+str(d.get(\"uptime\"))+\" heap=\"+str(d.get(\"heap_free\")))' 2>/dev/null || echo '  (status not JSON / chip not serving)'
      cc=\$(curl -s -m8 -o /tmp/cf.txt -w '%{http_code}' http://$2/api/config 2>/dev/null); echo \"/api/config HTTP=\$cc\"
      [ \"\$cc\" = 200 ] && python3 -c 'import json;d=json.load(open(\"/tmp/cf.txt\"));print(\"  config model=\"+str(d.get(\"model\")))' 2>/dev/null || echo '  (config not JSON)'" 2>&1
}
chk "$P2" 192.168.1.15 c6-02
chk "$P3" 192.168.1.47 c6-03
