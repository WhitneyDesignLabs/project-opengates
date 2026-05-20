#!/bin/bash
# Phase 3.3.3 N1: clone llama.cpp on azza (if absent), install convert deps,
# locate convert_lora_to_gguf.py. Run remotely via a heredoc'd script.
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=12 azza@192.168.1.60"
$A 'bash -s' <<'REMOTE' 2>&1
set -u
cd ~
if [ ! -d llama.cpp ]; then
  echo "cloning llama.cpp..."
  git clone --depth 1 https://github.com/ggerganov/llama.cpp.git 2>&1 | tail -3
else
  echo "llama.cpp already present ($(cd llama.cpp && git rev-parse --short HEAD 2>/dev/null || echo '?'))"
fi
cd ~/llama.cpp
echo "== locate convert_lora script =="
ls -la convert_lora_to_gguf.py 2>/dev/null || { echo "not at root; searching..."; find . -maxdepth 2 -iname '*convert*lora*' -type f; }
echo "== python deps =="
REQ=requirements/requirements-convert_lora_to_gguf.txt
[ -f "$REQ" ] && pip3 install --break-system-packages -q -r "$REQ" 2>&1 | tail -3 || {
  echo "req file $REQ absent; installing core deps"; pip3 install --break-system-packages -q numpy torch safetensors gguf sentencepiece transformers 2>&1 | tail -3; }
echo "== verify import + script help =="
python3 -c "import gguf, safetensors, torch; print('gguf/safetensors/torch import OK')" 2>&1
python3 convert_lora_to_gguf.py --help 2>&1 | head -5
echo "== ollama present? =="
which ollama && ollama --version 2>&1
ollama list 2>&1 | head -5
REMOTE
