#!/bin/bash
# Phase 4.2.1.C driver. Hybrid model: Scott provisions Brev H100 in
# browser and shares the SSH command; this script does the rest.
#
# Usage:
#   bash phase_4_2_1c_brev.sh <mode> "<ssh-target>"
#
# <ssh-target> is the bare argument you'd put after `ssh ` — e.g.
#   "brev@gpu-h100-xxxx.brev.dev -p 22"
#   "ubuntu@1.2.3.4"
# Quote it. The script extracts host+port via parsing and reuses it
# for ssh + scp.
#
# Modes (run in this order):
#   probe      — verify ssh + nvidia-smi + python + cuda + disk
#   setup      — pip install + HF_TOKEN export + HF access verify
#   upload     — scp v1.3 bundle to /home/<user>/wireclaw-training[-data]/
#   sanity     — load tokenizer + render one val example; load model 4-bit (no train)
#   train      — kick off training in a detached tmux session
#   monitor    — show last N lines of training log + status (one-shot)
#   download   — scp the wireclaw-v1.3-brev/ output back to workstation
#   all-prep   — probe + setup + upload + sanity (pre-train pipeline)
set -u

MODE="${1:-help}"
TARGET_RAW="${2:-}"

# Parse "<user>@<host> -p <port>" or "<user>@<host>" into vars
parse_target() {
  if [ -z "$TARGET_RAW" ]; then
    echo "FATAL: no <ssh-target> given." >&2
    exit 2
  fi
  PORT=22
  if echo "$TARGET_RAW" | grep -q "\-p "; then
    PORT=$(echo "$TARGET_RAW" | sed -E 's/.* -p +([0-9]+).*/\1/')
    USERHOST=$(echo "$TARGET_RAW" | sed -E 's/ +-p +[0-9]+//' | tr -d ' ')
  else
    USERHOST=$(echo "$TARGET_RAW" | tr -d ' ')
  fi
  USER_=${USERHOST%%@*}
  HOST=${USERHOST##*@}
  HOMEDIR="/home/$USER_"
  echo "  user: $USER_  host: $HOST  port: $PORT  home: $HOMEDIR"
}

SSH_KEY="${WIRECLAW_BREV_KEY:-$HOME/.ssh/id_ed25519}"
SSH() { ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=15 -p "$PORT" "$USERHOST" "$@"; }
SCP_PUT() { scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes -o ConnectTimeout=20 "$@" "$USERHOST:$REMOTE_TARGET"; }

case "$MODE" in
  probe)
    parse_target
    echo "== probing =="
    SSH 'echo CONNECTED; uname -a; nvidia-smi | head -n 15; python3 --version; nvcc --version 2>/dev/null | head -n 4; df -h / | tail -n 2'
    ;;

  setup)
    parse_target
    echo "== installing deps =="
    SSH 'pip install -U pip 2>&1 | tail -n 3 && \
         pip install -U torch transformers peft trl accelerate bitsandbytes datasets sentencepiece protobuf pyyaml 2>&1 | tail -n 5'
    echo
    echo "== exporting HF_TOKEN to ~/.wireclaw-env =="
    HF_TOKEN=$(python3 -c '
import re
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"\bhf_[A-Za-z0-9]{20,}", f.read())
print(m.group(0) if m else "")
')
    if [ -z "$HF_TOKEN" ]; then echo "FATAL: no HF_TOKEN"; exit 2; fi
    # Push via stdin to avoid token in argv / ps -ef
    printf 'export HF_TOKEN=%s\n' "$HF_TOKEN" | SSH "cat > ~/.wireclaw-env && chmod 600 ~/.wireclaw-env && echo wrote ~/.wireclaw-env"
    echo
    echo "== verify HF access =="
    SSH '. ~/.wireclaw-env && python3 -c "
import os
from huggingface_hub import HfApi
api = HfApi(token=os.environ[\"HF_TOKEN\"])
info = api.model_info(\"meta-llama/Llama-3.1-8B-Instruct\")
print(\"Access OK:\", info.modelId)
"'
    ;;

  upload)
    parse_target
    echo "== uploading bundle =="
    SSH "mkdir -p $HOMEDIR/wireclaw-training $HOMEDIR/wireclaw-training-data"
    cd /mnt/c/Users/homet/Documents/WireClaw

    REMOTE_TARGET="$USERHOST:$HOMEDIR/wireclaw-training/"
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes -o ConnectTimeout=20 -r \
      bench/fork/lora/training/train.py \
      bench/fork/lora/training/configs \
      "$REMOTE_TARGET"

    REMOTE_TARGET="$USERHOST:$HOMEDIR/wireclaw-training-data/"
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes -o ConnectTimeout=20 \
      bench/fork/lora/training-data/v1.3-train.jsonl \
      bench/fork/lora/training-data/wireclaw-v2-val.jsonl \
      "$REMOTE_TARGET"

    REMOTE_TARGET="$USERHOST:$HOMEDIR/wireclaw-training-data/constitution/"
    SSH "mkdir -p $HOMEDIR/wireclaw-training-data/constitution"
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes -o ConnectTimeout=20 \
      bench/fork/lora/training-data/constitution/SOUL-LOCAL.md \
      bench/fork/lora/training-data/constitution/SOUL-CHIP.md \
      "$REMOTE_TARGET"

    echo "== rewriting brev-v1.3.yaml paths to instance =="
    SSH "cd $HOMEDIR/wireclaw-training && python3 -c \"
import yaml
cfg = yaml.safe_load(open('configs/brev-v1.3.yaml'))
cfg['train_file'] = '$HOMEDIR/wireclaw-training-data/v1.3-train.jsonl'
cfg['val_file']   = '$HOMEDIR/wireclaw-training-data/wireclaw-v2-val.jsonl'
cfg['output_dir'] = '$HOMEDIR/wireclaw-training/output/wireclaw-v1.3-brev'
yaml.safe_dump(cfg, open('configs/brev-v1.3.yaml', 'w'), default_flow_style=False)
print(yaml.safe_dump(cfg, default_flow_style=False))
\""
    echo
    echo "== verifying =="
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
tokens = tok.apply_chat_template(ex['messages'], tokenize=True)
print(f'val example tokens: {len(tokens)}')
print('rendered head:', tok.apply_chat_template(ex['messages'], tokenize=False)[:200])
\""
    echo
    echo "== sanity: 4-bit load (this is the slow check ~3-5 min first time) =="
    SSH ". ~/.wireclaw-env && python3 -c \"
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type='nf4',
                          bnb_4bit_compute_dtype=torch.bfloat16,
                          bnb_4bit_use_double_quant=True)
m = AutoModelForCausalLM.from_pretrained('meta-llama/Llama-3.1-8B-Instruct',
                                          quantization_config=bnb,
                                          torch_dtype=torch.bfloat16)
print('model loaded in 4-bit. vram used:',
      torch.cuda.memory_allocated() / 1e9, 'GB')
\""
    ;;

  train)
    parse_target
    echo "== launching training in tmux session 'wirec-v1_3' =="
    REMOTE_CMD="cd $HOMEDIR/wireclaw-training && . ~/.wireclaw-env && \
      python3 -u train.py --config configs/brev-v1.3.yaml 2>&1 | \
      tee $HOMEDIR/wireclaw-training/output/_train.log; \
      echo EXITCODE=\$? > $HOMEDIR/wireclaw-training/output/_done.txt"
    SSH "mkdir -p $HOMEDIR/wireclaw-training/output && \
         tmux kill-session -t wirec-v1_3 2>/dev/null; \
         tmux new-session -d -s wirec-v1_3 '$REMOTE_CMD'; \
         sleep 2; \
         tmux list-sessions | grep wirec || echo NO-TMUX-SESSION"
    echo
    echo "tmux session started. Use 'monitor' mode to peek progress."
    ;;

  monitor)
    parse_target
    echo "== tmux session status =="
    SSH "tmux list-sessions 2>/dev/null | grep wirec || echo no-tmux-session"
    echo
    echo "== last 30 lines of training output =="
    SSH "tmux capture-pane -t wirec-v1_3 -p 2>/dev/null | tail -n 30 || cat $HOMEDIR/wireclaw-training/output/_train.log 2>/dev/null | tail -n 30 || echo no-log"
    echo
    echo "== done flag =="
    SSH "[ -f $HOMEDIR/wireclaw-training/output/_done.txt ] && cat $HOMEDIR/wireclaw-training/output/_done.txt || echo still-running"
    ;;

  download)
    parse_target
    LOCAL_OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/wireclaw-v1.3-brev
    mkdir -p "$LOCAL_OUT"
    echo "== downloading adapter to $LOCAL_OUT =="
    scp -i "$SSH_KEY" -o IdentitiesOnly=yes -P "$PORT" -o BatchMode=yes -o ConnectTimeout=20 -r \
      "$USERHOST:$HOMEDIR/wireclaw-training/output/wireclaw-v1.3-brev/." \
      "$LOCAL_OUT/"
    echo
    echo "== content =="
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
    echo "Example: $0 all-prep \"brev@gpu-xxxx.brev.dev -p 22\""
    echo "         $0 train    \"brev@gpu-xxxx.brev.dev -p 22\""
    ;;
esac
