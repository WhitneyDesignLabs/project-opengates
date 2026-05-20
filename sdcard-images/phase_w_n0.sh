#!/bin/bash
# Phase 3.3.3 N0: extract v2 adapter package, scp to azza + constitution/template.
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=10 azza@192.168.1.60"
SC="scp -q -o BatchMode=yes -o ConnectTimeout=10"
OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output
TD=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data
TR=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training

cd "$OUT" || exit 2
tar xzf wireclaw-v2-package.tar.gz
DIR=$(find "$OUT" -type d -name wireclaw-v2-brev | head -1)
echo "extracted adapter dir: $DIR"
echo "== adapter files =="
ls -la "$DIR"
echo "== required-file presence =="
for f in adapter_model.safetensors adapter_config.json tokenizer.json tokenizer_config.json training-config.yaml training-log.json; do
  [ -f "$DIR/$f" ] && echo "  OK  $f ($(stat -c%s "$DIR/$f") B)" || echo "  MISSING $f"
done
[ -f "$DIR/chat_template.jinja" ] && echo "  OK  chat_template.jinja" || echo "  note: chat_template.jinja absent (may be inlined in tokenizer_config.json)"

echo "== azza reachability =="
$A 'hostname; uptime | sed "s/^/  /"' 2>&1 || { echo "FATAL: azza unreachable"; exit 3; }

echo "== scp adapter dir -> azza:~/wireclaw-v2-brev =="
$A 'rm -rf ~/wireclaw-v2-brev; mkdir -p ~/wireclaw-v2-brev' 2>&1
$SC -r "$DIR"/. azza@192.168.1.60:~/wireclaw-v2-brev/ 2>&1 && echo "  adapter scp OK" || echo "  adapter scp FAIL"
$SC "$TD/constitution/SOUL-CHIP.md" azza@192.168.1.60:~/SOUL-CHIP.md 2>&1 && echo "  SOUL-CHIP scp OK" || echo "  SOUL-CHIP scp FAIL"
$SC "$TR/wireclaw-agent-v1.1.Modelfile.template" azza@192.168.1.60:~/Modelfile.template 2>&1 && echo "  template scp OK" || echo "  template scp FAIL"

echo "== verify on azza =="
$A 'echo "-- ~/wireclaw-v2-brev --"; ls -la ~/wireclaw-v2-brev/; echo "-- aux --"; ls -la ~/SOUL-CHIP.md ~/Modelfile.template' 2>&1
