#!/bin/bash
# Phase 3.3.4 N0+N1 (Path A: c6-02, c6-03 only). Per chip, FROM its paired Pi:
#  N0 GET /api/config (baseline model) ; N1 POST model=wireclaw-agent:v1.1,
#  reboot, wait, GET verify. /api/config merges (single-field POST safe; wifi
#  preserved). No auth on /api/* (confirmed in fork source).
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$S scott@192.168.1.17"   # pi02 -> c6-02 .15
P3="$S scott@192.168.1.44"   # pi03 -> c6-03 .47
NEW="wireclaw-agent:v1.1"

swap() {  # $1 pi-ssh  $2 chip-ip  $3 label
  echo "================= $3 ($2) ================="
  $1 "set -u
    echo '-- N0 baseline /api/config --'
    curl -s -m8 http://$2/api/config 2>/dev/null | python3 -c 'import sys,json;d=json.load(sys.stdin);print({k:d.get(k) for k in (\"model\",\"api_base_url\",\"device_name\",\"wifi_ssid\")})' || { echo CONFIG_GET_FAIL; exit 1; }
    echo '-- N1 POST model=$NEW --'
    curl -s -m8 -X POST http://$2/api/config -H 'Content-Type: application/json' -d '{\"model\":\"$NEW\"}' 2>/dev/null; echo
    echo '-- POST /api/reboot --'
    curl -s -m8 -X POST http://$2/api/reboot 2>/dev/null; echo
  " 2>&1
  echo "-- waiting for $3 to come back (up to ~3 min) --"
  $1 "for i in \$(seq 1 18); do
        if curl -s -m5 -o /dev/null -w '%{http_code}' http://$2/api/status 2>/dev/null | grep -q 200; then echo \"  back after ~\$((i*10))s\"; break; fi
        sleep 10
      done
    echo '-- N1 verify /api/config + /api/status --'
    curl -s -m8 http://$2/api/config 2>/dev/null | python3 -c 'import sys,json;d=json.load(sys.stdin);print(\"model=\"+str(d.get(\"model\"))+\" api_base=\"+str(d.get(\"api_base_url\"))+\" wifi=\"+str(d.get(\"wifi_ssid\")))'
    curl -s -m8 http://$2/api/status 2>/dev/null | python3 -c 'import sys,json;d=json.load(sys.stdin);print(\"status: model=\"+str(d.get(\"model\"))+\" up=\"+str(d.get(\"uptime\"))+\" heap=\"+str(d.get(\"heap_free\")))'" 2>&1
}
swap "$P2" 192.168.1.15 c6-02
swap "$P3" 192.168.1.47 c6-03
