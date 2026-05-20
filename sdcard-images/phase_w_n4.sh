#!/bin/bash
# Phase 3.3.3 N4: ollama create wireclaw-agent:v1.1 on azza.
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=12 azza@192.168.1.60"
$A 'bash -s' <<'REMOTE' 2>&1
set -u
cd ~
echo "== base llama3.1:8b present? =="
ollama list | grep -E 'llama3.1:8b|^NAME' || echo "(llama3.1:8b not listed — ollama create will pull or fail)"
echo "== ollama create wireclaw-agent:v1.1 =="
ollama create wireclaw-agent:v1.1 -f ~/wireclaw-agent-v1.1.Modelfile 2>&1 | tail -20
echo "== ollama list (wireclaw) =="
ollama list | grep -E '^NAME|wireclaw'
echo "== ollama show wireclaw-agent:v1.1 (system head) =="
ollama show wireclaw-agent:v1.1 2>&1 | head -25
REMOTE
