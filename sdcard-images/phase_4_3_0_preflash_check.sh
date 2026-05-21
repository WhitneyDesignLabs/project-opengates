#!/bin/bash
# Phase 4.3.0.D pre-flash safety check for c6-01.
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"

echo "=== c6-01 current state (target) ==="
curl -sS --max-time 5 http://192.168.1.19/api/status | python3 -m json.tool 2>/dev/null || echo "  no response"
echo
echo "-- /api/config --"
curl -sS --max-time 5 http://192.168.1.19/api/config | python3 -m json.tool 2>/dev/null || echo "  no response"
echo
echo "-- /api/rules (current store, snapshot for rollback) --"
curl -sS --max-time 5 http://192.168.1.19/api/rules
echo
echo "-- /api/memory (current memory contents, snapshot) --"
curl -sS --max-time 5 http://192.168.1.19/api/memory
echo

echo
echo "=== c6-02 + c6-03 untouched-check ==="
for ip in 192.168.1.15 192.168.1.47; do
  printf "  chip %s: " "$ip"
  curl -sS --max-time 5 "http://$ip/api/status" | grep -oE '"(version|model|uptime)":[^,}]+' | tr '\n' ' '
  echo
done

echo
echo "=== evobot rollback binaries (bf80fa9, sha aa531aa2...) ==="
$SSH "scott@192.168.1.51" "
for f in firmware-bf80fa9.bin bootloader.bin partitions.bin boot_app0.bin; do
  if [ -f ~/\$f ]; then
    SHA=\$(sha256sum ~/\$f | awk '{print \$1}')
    SZ=\$(stat -c '%s' ~/\$f)
    echo \"  \$f present (\$SZ bytes, sha \${SHA:0:16}...)\"
  else
    echo \"  \$f MISSING\"
  fi
done
"

echo
echo "=== firmware build artifacts on workstation (3f15cc15) ==="
ls -la /mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6/firmware.bin \
       /mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6/bootloader.bin \
       /mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6/partitions.bin \
       /mnt/c/Users/homet/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin 2>&1 | tail -n 6
echo
echo "  firmware.bin sha256:"
sha256sum /mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6/firmware.bin
