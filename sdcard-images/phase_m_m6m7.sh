#!/bin/bash
# Phase 3.1.3 M6 (combined report + 3.1.2 compare) and M7 (fleet health + anomaly dig).
set -u
BENCH="/mnt/c/Users/homet/Documents/WireClaw/bench"
OUT="$BENCH/fork/lora/corpus-raw"
J="$HOME/3.1.3-jsonl"
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"
A="ssh -o BatchMode=yes -o ConnectTimeout=8 azza@192.168.1.60"
WIN_H=10.78

echo "================ M6: COMBINED 3.1.3 + vs 3.1.2 ================"
python3 - "$OUT" "$WIN_H" <<'PY'
import sys, json, glob, os
OUT, WIN = sys.argv[1], float(sys.argv[2])
def load(p):
    return json.load(open(p)) if os.path.exists(p) else None
tot=0; rec=0
print("3.1.3 per-chip (windowed %.2fh):"%WIN)
for lbl in ['pilot','c6-02','c6-03']:
    d=load(f"{OUT}/3.1.3-2026-05-16-{lbl}.json")
    n=d['turns']['total']; r=d['proxy_stats']['record_count']
    lat=d['proxy_stats']['latency_ms']; lc=d['label_counts']
    tot+=n; rec+=r
    unc=lc.get('uncertain',0)
    print(f"  {lbl:7} turns={n:5} rec={r:5} {n/WIN:6.1f} t/hr  "
          f"p50={lat['p50']}ms p95={lat['p95']}ms  "
          f"uncertain={unc} ({100*unc/max(n,1):.0f}%) "
          f"clean={lc.get('clean',0)} fab={lc.get('fabricated',0)} pp={lc.get('pseudo-prose',0)}")
print(f"\n  COMBINED: turns={tot}  proxy_records={rec}  "
      f"aggregate={tot/WIN:.1f} t/hr  (~{tot/WIN/3:.1f} t/hr/chip avg)")
print(f"  Directive on-target band: 1200-2200 combined turns -> got {tot} "
      f"({'ABOVE band (more corpus)' if tot>2200 else 'in band' if tot>=1200 else 'BELOW band'})")
print("\n3.1.2 reference (prior multipair, same chips):")
for lbl in ['pilot','c6-02','c6-03']:
    d=load(f"{OUT}/multipair-3.1.2-2026-05-16-{lbl}.json")
    if not d: print(f"  {lbl}: (missing)"); continue
    n=d.get('turns',{}).get('total','?'); tph=d.get('turns',{}).get('throughput_per_hour','?')
    print(f"  {lbl:7} turns={n} thr={tph} t/hr")
PY

echo
echo "JSONL-truth (user-side, all 3 Pis, 3.1.3 window): 443 sessions / 4430 turns / 82 timeouts"
echo "  -> proxy reconstructs 3601 turns; gap = multi-call turns merged + sub-prompt sessions"

echo
echo "================ M7: FLEET HEALTH ================"
echo "--- EvoBot ---"
$EVO 'echo -n "temp="; awk "{printf \"%.1fC\", \$1/1000}" /sys/class/thermal/thermal_zone0/temp; echo -n "  throttled="; vcgencmd get_throttled 2>/dev/null; free -h | awk "/Mem:/{print \"  mem used/total=\"\$3\"/\"\$2}"; uptime | sed "s/^/  /"' 2>&1
echo "--- pi02 ---"
$P2 'echo -n "temp="; awk "{printf \"%.1fC\", \$1/1000}" /sys/class/thermal/thermal_zone0/temp; echo -n "  throttled="; vcgencmd get_throttled 2>/dev/null; free -h | awk "/Mem:/{print \"  mem used/total=\"\$3\"/\"\$2}"; uptime | sed "s/^/  /"' 2>&1
echo "--- pi03 ---"
$P3 'echo -n "temp="; awk "{printf \"%.1fC\", \$1/1000}" /sys/class/thermal/thermal_zone0/temp; echo -n "  throttled="; vcgencmd get_throttled 2>/dev/null; free -h | awk "/Mem:/{print \"  mem used/total=\"\$3\"/\"\$2}"; uptime | sed "s/^/  /"' 2>&1

echo
echo "--- chip survival (/api/status) ---"
for ip in 192.168.1.19 192.168.1.15 192.168.1.47; do
  echo -n "  chip $ip: "
  curl -fsS --max-time 6 "http://$ip/api/status" 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print({k:d.get(k) for k in ('version','fw','uptime','uptime_s','heap','free_heap')})" 2>/dev/null || echo "NO RESPONSE / unreachable"
done

echo
echo "--- azza proxy + disk ---"
$A 'systemctl --user status wireclaw-ollama-proxy.service 2>/dev/null | grep -E "Active:|Main PID:"; df -h $HOME | tail -1; du -sh ~/wireclaw-corpus/ 2>/dev/null' 2>&1

echo
echo "--- ANOMALY: rule-purge FAILED count + time span per Pi ---"
for L in evobot pi02 pi03; do
  f="$J/$L.3.1.3.log"
  [ -f "$f" ] || { echo "  $L: no log"; continue; }
  n=$(grep -c 'rule-purge FAILED' "$f")
  first=$(grep -m1 'rule-purge FAILED' "$f" | sed -E 's/: rule-purge.*//')
  last=$(grep 'rule-purge FAILED' "$f" | tail -1 | sed -E 's/: rule-purge.*//')
  tot=$(grep -c 'rule-purge' "$f")
  echo "  $L: rule-purge total=$tot  FAILED=$n  first_fail=[$first]  last_fail=[$last]"
done
echo "  (rule-purge FAILED = session-start chip /api/rules/delete didn't ACK; loop continued)"
