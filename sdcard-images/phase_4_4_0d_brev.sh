#!/bin/bash
# Phase 4.4.0.D driver. Same modes/shape as phase_4_2_1g_brev.sh but
# wired for v1.3.2 paths and tmux session name.
#
# Usage: bash phase_4_4_0d_brev.sh <mode> "<ssh-target>"
# Modes: probe | setup | upload | sanity | train | monitor | download | all-prep
set -u
MODE="${1:-help}"
TARGET_RAW="${2:-}"

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
  echo "  user: $USER_  host: ${USERHOST##*@}  port: $PORT  home: $HOMEDIR"
}

SSH_KEY="${WIRECLAW_BREV_KEY:-$HOME/.ssh/id_ed25519}"
# Connect by IP, so Brev's Host-alias config block does not apply; replicate
# its host-key handling here (ephemeral cloud IP, no persistent known_hosts).
HKOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH() { ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes $HKOPTS -o ConnectTimeout=15 -o ServerAliveInterval=15 -p "$PORT" "$USERHOST" "$@"; }

case "$MODE" in
  probe)
    parse_target
    SSH 'echo CONNECTED; uname -a; nvidia-smi | head -n 15; python3 --version; df -h / | tail -n 2'
    ;;

  setup)
    parse_target
    echo "== installing/upgrading deps (cu128 torch + jinja2 + bitsandbytes + kernels) =="
    # This base image marks system Python as externally-managed (PEP 668);
    # ephemeral single-purpose GPU box, so --break-system-packages is fine.
    SSH 'pip install -U pip --break-system-packages 2>&1 | tail -n 2'
    SSH 'pip install --index-url https://download.pytorch.org/whl/cu128 -U torch torchvision torchaudio --break-system-packages 2>&1 | tail -n 5'
    SSH 'pip install -U "jinja2>=3.1.0" transformers peft trl accelerate bitsandbytes datasets sentencepiece protobuf pyyaml kernels --break-system-packages 2>&1 | tail -n 5'
    echo "== exporting HF_TOKEN =="
    HF_TOKEN=$(python3 -c '
import re
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"\bhf_[A-Za-z0-9]{20,}", f.read())
print(m.group(0) if m else "")
')
    [ -z "$HF_TOKEN" ] && { echo "FATAL: no HF_TOKEN"; exit 2; }
    printf 'export HF_TOKEN=%s\n' "$HF_TOKEN" | SSH "cat > ~/.wireclaw-env && chmod 600 ~/.wireclaw-env && echo wrote ~/.wireclaw-env"
    SSH '. ~/.wireclaw-env && python3 -c "
import os
from huggingface_hub import HfApi
api = HfApi(token=os.environ[\"HF_TOKEN\"])
print(\"Access OK:\", api.model_info(\"meta-llama/Llama-3.1-8B-Instruct\").modelId)
"'
    ;;

  upload)
    parse_target
    echo "== uploading v1.3.2 bundle =="
    SSH "mkdir -p $HOMEDIR/wireclaw-training $HOMEDIR/wireclaw-training-data $HOMEDIR/wireclaw-training-data/constitution"
    cd /mnt/c/Users/homet/Documents/WireClaw
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes $HKOPTS -r \
      bench/fork/lora/training/train.py \
      bench/fork/lora/training/configs \
      "$USERHOST:$HOMEDIR/wireclaw-training/"
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes $HKOPTS \
      bench/fork/lora/training-data/v1.3.2-train.jsonl \
      bench/fork/lora/training-data/wireclaw-v2-val.jsonl \
      "$USERHOST:$HOMEDIR/wireclaw-training-data/"
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes $HKOPTS \
      bench/fork/lora/training-data/constitution/SOUL-LOCAL.md \
      bench/fork/lora/training-data/constitution/SOUL-CHIP.md \
      "$USERHOST:$HOMEDIR/wireclaw-training-data/constitution/"

    echo "== rewriting brev-v1.3.2.yaml paths to match instance HOMEDIR =="
    SSH "cd $HOMEDIR/wireclaw-training && python3 -c \"
import yaml
cfg = yaml.safe_load(open('configs/brev-v1.3.2.yaml'))
cfg['train_file'] = '$HOMEDIR/wireclaw-training-data/v1.3.2-train.jsonl'
cfg['val_file']   = '$HOMEDIR/wireclaw-training-data/wireclaw-v2-val.jsonl'
cfg['output_dir'] = '$HOMEDIR/wireclaw-training/output/wireclaw-v1.3.2-brev'
yaml.safe_dump(cfg, open('configs/brev-v1.3.2.yaml', 'w'), default_flow_style=False)
print(yaml.safe_dump(cfg, default_flow_style=False))
\""
    SSH "ls -la $HOMEDIR/wireclaw-training/ $HOMEDIR/wireclaw-training-data/"
    ;;

  sanity)
    parse_target
    echo "== sanity: tokenize one val example =="
    SSH ". ~/.wireclaw-env && python3 -c \"
import json
from transformers import AutoTokenizer
tok = AutoTokenizer.from_pretrained('meta-llama/Llama-3.1-8B-Instruct')
ex = json.loads(open('$HOMEDIR/wireclaw-training-data/wireclaw-v2-val.jsonl').readline())
print('rendered head:', tok.apply_chat_template(ex['messages'], tokenize=False)[:200])
\""
    echo "== sanity: 4-bit GPU load =="
    SSH ". ~/.wireclaw-env && python3 -c \"
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type='nf4',
                          bnb_4bit_compute_dtype=torch.bfloat16,
                          bnb_4bit_use_double_quant=True)
m = AutoModelForCausalLM.from_pretrained('meta-llama/Llama-3.1-8B-Instruct',
                                          quantization_config=bnb,
                                          torch_dtype=torch.bfloat16,
                                          device_map='auto')
print('vram allocated:', torch.cuda.memory_allocated()/1e9, 'GB')
print('device:', next(m.parameters()).device)
\" 2>&1 | tail -n 10"
    ;;

  train)
    parse_target
    echo "== launching v1.3.2 training in tmux session 'wirec-v132' =="
    REMOTE_CMD="cd $HOMEDIR/wireclaw-training && . ~/.wireclaw-env && \
      python3 -u train.py --config configs/brev-v1.3.2.yaml 2>&1 | \
      tee $HOMEDIR/wireclaw-training/output/_train_v132.log; \
      echo EXITCODE=\$? > $HOMEDIR/wireclaw-training/output/_done_v132.txt"
    SSH "mkdir -p $HOMEDIR/wireclaw-training/output && \
         tmux kill-session -t wirec-v132 2>/dev/null; \
         tmux new-session -d -s wirec-v132 '$REMOTE_CMD'; \
         sleep 2; tmux list-sessions | grep wirec || echo NO-TMUX-SESSION"
    ;;

  monitor)
    parse_target
    SSH "tmux list-sessions 2>/dev/null | grep wirec || echo no-tmux-session"
    echo
    SSH "tmux capture-pane -t wirec-v132 -p 2>/dev/null | tail -n 30 || cat $HOMEDIR/wireclaw-training/output/_train_v132.log 2>/dev/null | tail -n 30 || echo no-log"
    echo
    SSH "[ -f $HOMEDIR/wireclaw-training/output/_done_v132.txt ] && cat $HOMEDIR/wireclaw-training/output/_done_v132.txt || echo still-running"
    ;;

  download)
    parse_target
    LOCAL_OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/wireclaw-v1.3.2-brev
    rm -rf "$LOCAL_OUT"
    mkdir -p "$(dirname "$LOCAL_OUT")"
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes $HKOPTS -r \
        "$USERHOST:$HOMEDIR/wireclaw-training/output/wireclaw-v1.3.2-brev" \
        "$(dirname "$LOCAL_OUT")/"
    ls -la "$LOCAL_OUT/"
    ;;

  all-prep)
    bash "$0" probe   "$TARGET_RAW"
    echo; bash "$0" setup   "$TARGET_RAW"
    echo; bash "$0" upload  "$TARGET_RAW"
    echo; bash "$0" sanity  "$TARGET_RAW"
    ;;

  help|*)
    echo "Usage: $0 <mode> \"<ssh-target>\""
    echo "Modes: probe | setup | upload | sanity | train | monitor | download | all-prep"
    ;;
esac
