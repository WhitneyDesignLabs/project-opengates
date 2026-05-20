#!/bin/bash
# Phase 4.2.1.C dep-fix: upgrade jinja2 + reinstall torch+bitsandbytes
# with cu128 wheels (matches driver 570.195.03 / CUDA 12.8 on the Brev
# H100 instance). Re-runs the 4-bit GPU load sanity.
set -u
TARGET="${1:-shadeform@185.216.22.114}"
SSH_KEY="${WIRECLAW_BREV_KEY:-$HOME/.ssh/id_ed25519}"
PORT=22

SSH() { ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15 -p "$PORT" "$TARGET" "$@"; }

echo "== upgrading jinja2 =="
SSH 'pip install -U "jinja2>=3.1.0" 2>&1 | tail -n 3'

echo
echo "== reinstalling torch with cu128 wheels =="
SSH 'pip install --index-url https://download.pytorch.org/whl/cu128 -U torch torchvision torchaudio 2>&1 | tail -n 10'

echo
echo "== reinstalling bitsandbytes (latest, matches cu128 torch) =="
SSH 'pip install -U bitsandbytes kernels 2>&1 | tail -n 5'

echo
echo "== verify torch sees cuda =="
SSH '. ~/.wireclaw-env && python3 -c "
import torch
print(f\"torch {torch.__version__}\")
print(f\"cuda available: {torch.cuda.is_available()}\")
print(f\"cuda runtime: {torch.version.cuda}\")
print(f\"device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else None}\")
print(f\"compute capability: {torch.cuda.get_device_capability(0) if torch.cuda.is_available() else None}\")
"'

echo
echo "== re-running 4-bit GPU load sanity =="
SSH '. ~/.wireclaw-env && python3 -c "
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
bnb = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_quant_type=\"nf4\",
                         bnb_4bit_compute_dtype=torch.bfloat16,
                         bnb_4bit_use_double_quant=True)
m = AutoModelForCausalLM.from_pretrained(\"meta-llama/Llama-3.1-8B-Instruct\",
                                          quantization_config=bnb,
                                          torch_dtype=torch.bfloat16,
                                          device_map=\"auto\")
print(\"model loaded in 4-bit.\")
print(\"vram allocated:\", torch.cuda.memory_allocated() / 1e9, \"GB\")
print(\"vram reserved :\", torch.cuda.memory_reserved() / 1e9, \"GB\")
print(\"device:\", next(m.parameters()).device)
" 2>&1 | tail -n 15'

echo
echo "== re-running tokenize sanity =="
SSH '. ~/.wireclaw-env && python3 -c "
import json
from transformers import AutoTokenizer
tok = AutoTokenizer.from_pretrained(\"meta-llama/Llama-3.1-8B-Instruct\")
ex = json.loads(open(\"/home/shadeform/wireclaw-training-data/wireclaw-v2-val.jsonl\").readline())
tokens = tok.apply_chat_template(ex[\"messages\"], tokenize=True)
print(f\"val example tokens: {len(tokens)}\")
print(\"rendered head:\", tok.apply_chat_template(ex[\"messages\"], tokenize=False)[:200])
"'
