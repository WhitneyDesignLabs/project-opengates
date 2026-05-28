#!/bin/bash
# Phase 4.4.0.D step: convert v1.3.2 LoRA -> GGUF (on instance), download,
# push to azza, render Modelfile, ollama create wireclaw-agent:v1.3.2.
# Mirrors phase_4_2_1g_build.sh with v1.3.2 paths. Modelfile uses the v1.3
# template (NO 4.3.0.H wrap-policy paragraph — that experiment was abandoned).
set -u
MODE="${1:-help}"
TARGET_RAW="${2:-}"
SSH_KEY="${WIRECLAW_BREV_KEY:-$HOME/.brev/brev.pem}"
# Connect by IP -> Brev Host-alias block does not apply; handle host key here.
HKOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

parse_target() {
  [ -z "$TARGET_RAW" ] && { echo "FATAL: no <ssh-target>"; exit 2; }
  PORT=22
  if echo "$TARGET_RAW" | grep -q "\-p "; then
    PORT=$(echo "$TARGET_RAW" | sed -E 's/.* -p +([0-9]+).*/\1/')
    USERHOST=$(echo "$TARGET_RAW" | sed -E 's/ +-p +[0-9]+//' | tr -d ' ')
  else
    USERHOST=$(echo "$TARGET_RAW" | tr -d ' ')
  fi
  USER_=${USERHOST%%@*}
  HOMEDIR="/home/$USER_"
}
SSH() { ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes $HKOPTS -o ConnectTimeout=15 -p "$PORT" "$USERHOST" "$@"; }

case "$MODE" in
  convert)
    parse_target
    echo "== installing convert deps =="
    SSH '. ~/.wireclaw-env && pip install -U gguf safetensors --break-system-packages 2>&1 | tail -n 3'
    echo
    echo "== cloning llama.cpp if needed =="
    SSH "cd ~ && [ -d llama.cpp ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp.git 2>&1 | tail -n 3"
    echo
    echo "== running convert_lora_to_gguf.py =="
    SSH ". ~/.wireclaw-env && cd ~/llama.cpp && python3 convert_lora_to_gguf.py \
         --base-model-id meta-llama/Llama-3.1-8B-Instruct \
         --outtype f16 \
         $HOMEDIR/wireclaw-training/output/wireclaw-v1.3.2-brev 2>&1 | tail -n 15"
    echo
    SSH "ls -la $HOMEDIR/wireclaw-training/output/wireclaw-v1.3.2-brev/*.gguf"
    ;;

  download)
    parse_target
    LOCAL_OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/wireclaw-v1.3.2-brev
    mkdir -p "$LOCAL_OUT"
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes $HKOPTS \
      "$USERHOST:$HOMEDIR/wireclaw-training/output/wireclaw-v1.3.2-brev/*.gguf" \
      "$LOCAL_OUT/"
    ls -la "$LOCAL_OUT/"*.gguf
    ;;

  deploy)
    LOCAL_GGUF=$(ls /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/wireclaw-v1.3.2-brev/*.gguf 2>/dev/null | head -n 1)
    [ -z "$LOCAL_GGUF" ] && { echo "FATAL: no GGUF locally"; exit 2; }
    echo "GGUF: $LOCAL_GGUF"
    echo "== uploading GGUF to azza =="
    scp -o BatchMode=yes "$LOCAL_GGUF" \
        azza@azza.tail63f48.ts.net:/home/azza/wireclaw-v1.3.2.gguf
    echo
    echo "== rendering Modelfile =="
    TPL=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/wireclaw-agent-v1.3.Modelfile.template
    SOUL_CHIP=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/constitution/SOUL-CHIP.md
    RENDERED=/tmp/wireclaw-agent-v1.3.2.Modelfile
    python3 - "$TPL" "$SOUL_CHIP" "$RENDERED" <<'PY'
import sys, datetime
tpl_path, soul_path, out_path = sys.argv[1:4]
tpl = open(tpl_path).read()
soul = open(soul_path).read()
out = tpl.replace("<BUILD_DATE>", datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))
out = out.replace("<PATH_TO_V1.3_LORA_GGUF>", "/home/azza/wireclaw-v1.3.2.gguf")
out = out.replace("<SOUL_CHIP_INLINE>", soul.strip())
# v1.3.2 banner override
out = out.replace("# wireclaw-agent v1.3 ", "# wireclaw-agent v1.3.2 ")
out = out.replace("v1.3 LoRA (targeted constitutional repair)",
                  "v1.3.2 LoRA (action-claim fabrication suppression + memory-chain completion)")
open(out_path, "w").write(out)
print(f"wrote {out_path} ({len(out)} bytes)")
PY
    echo
    echo "== uploading Modelfile + ollama create =="
    scp -o BatchMode=yes "$RENDERED" azza@azza.tail63f48.ts.net:/home/azza/wireclaw-agent-v1.3.2.Modelfile
    ssh -o BatchMode=yes azza@azza.tail63f48.ts.net \
        "ollama create wireclaw-agent:v1.3.2 -f /home/azza/wireclaw-agent-v1.3.2.Modelfile 2>&1 | tail -n 15"
    echo
    ssh -o BatchMode=yes azza@azza.tail63f48.ts.net "ollama list | grep wireclaw"
    ;;

  help|*)
    echo "Usage: $0 convert|download|deploy [<ssh-target>]"
    ;;
esac
