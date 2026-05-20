#!/bin/bash
# Phase 4.2.1.D step 1: convert v1.3 LoRA adapter to GGUF, render Modelfile,
# push to azza, ollama create wireclaw-agent:v1.3.
#
# Usage:
#   bash phase_4_2_1d_build.sh convert "<brev-ssh-target>"   # on Brev: clone llama.cpp + convert
#   bash phase_4_2_1d_build.sh download "<brev-ssh-target>"  # bring GGUF + adapter back
#   bash phase_4_2_1d_build.sh deploy                        # scp to azza + ollama create
set -u

MODE="${1:-help}"
TARGET_RAW="${2:-}"
SSH_KEY="${WIRECLAW_BREV_KEY:-$HOME/.ssh/id_ed25519}"

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
SSH() { ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15 -p "$PORT" "$USERHOST" "$@"; }

case "$MODE" in
  convert)
    # On Brev: clone llama.cpp (just the convert scripts), pip install gguf, run convert
    parse_target
    echo "== installing convert deps on Brev =="
    SSH '. ~/.wireclaw-env && pip install -U gguf safetensors 2>&1 | tail -n 3'
    echo
    echo "== cloning llama.cpp (sparse, just convert scripts) =="
    SSH "cd ~ && [ -d llama.cpp ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp.git 2>&1 | tail -n 5"
    echo
    echo "== running convert_lora_to_gguf.py =="
    SSH ". ~/.wireclaw-env && cd ~/llama.cpp && python3 convert_lora_to_gguf.py \
         --base-model-id meta-llama/Llama-3.1-8B-Instruct \
         --outtype f16 \
         $HOMEDIR/wireclaw-training/output/wireclaw-v1.3-brev 2>&1 | tail -n 20"
    echo
    echo "== verify gguf exists =="
    SSH "ls -la $HOMEDIR/wireclaw-training/output/wireclaw-v1.3-brev/*.gguf"
    ;;

  download)
    parse_target
    LOCAL_OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/wireclaw-v1.3-brev
    mkdir -p "$LOCAL_OUT"
    echo "== downloading adapter + gguf =="
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes -r \
      "$USERHOST:$HOMEDIR/wireclaw-training/output/wireclaw-v1.3-brev/." \
      "$LOCAL_OUT/"
    ls -la "$LOCAL_OUT/"
    ;;

  deploy)
    # On azza: scp the GGUF, render Modelfile, ollama create.
    LOCAL_GGUF=$(ls /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/wireclaw-v1.3-brev/*.gguf 2>/dev/null | head -n 1)
    if [ -z "$LOCAL_GGUF" ]; then echo "FATAL: no GGUF in local v1.3-brev output dir"; exit 2; fi
    echo "GGUF: $LOCAL_GGUF"
    echo "== uploading GGUF to azza =="
    scp -o BatchMode=yes "$LOCAL_GGUF" \
      azza@azza.tail63f48.ts.net:/home/azza/wireclaw-v1.3.gguf
    echo
    echo "== rendering Modelfile with inlined SOUL-CHIP =="
    TPL=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/wireclaw-agent-v1.3.Modelfile.template
    SOUL_CHIP=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/constitution/SOUL-CHIP.md
    RENDERED=/tmp/wireclaw-agent-v1.3.Modelfile
    python3 - "$TPL" "$SOUL_CHIP" "$RENDERED" <<'PY'
import sys, datetime
tpl_path, soul_path, out_path = sys.argv[1:4]
tpl = open(tpl_path).read()
soul = open(soul_path).read()
out = tpl.replace("<BUILD_DATE>", datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))
out = out.replace("<PATH_TO_V1.3_LORA_GGUF>", "/home/azza/wireclaw-v1.3.gguf")
out = out.replace("<SOUL_CHIP_INLINE>", soul.strip())
open(out_path, "w").write(out)
print(f"wrote {out_path} ({len(out)} bytes)")
PY
    echo
    echo "== uploading Modelfile to azza =="
    scp -o BatchMode=yes "$RENDERED" azza@azza.tail63f48.ts.net:/home/azza/wireclaw-agent-v1.3.Modelfile
    echo
    echo "== ollama create on azza =="
    ssh -o BatchMode=yes azza@azza.tail63f48.ts.net \
        "ollama create wireclaw-agent:v1.3 -f /home/azza/wireclaw-agent-v1.3.Modelfile 2>&1 | tail -n 20"
    echo
    echo "== verify =="
    ssh -o BatchMode=yes azza@azza.tail63f48.ts.net "ollama list | grep wireclaw"
    ;;

  help|*)
    echo "Usage: $0 convert|download|deploy [<ssh-target>]"
    echo "  convert  — on Brev, run llama.cpp convert_lora_to_gguf.py"
    echo "  download — bring v1.3-brev/ dir + GGUF back to workstation"
    echo "  deploy   — scp GGUF + render Modelfile + ollama create on azza"
    ;;
esac
