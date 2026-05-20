#!/bin/bash
# Phase 3.2 N1/N3: locate ANTHROPIC_API_KEY (no API spend). Read-only.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"

echo "== 1. env in this (non-interactive) WSL shell =="
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ANTHROPIC_API_KEY present in env: ${ANTHROPIC_API_KEY:0:12}... (len ${#ANTHROPIC_API_KEY})"
else
  echo "ANTHROPIC_API_KEY: (NOT set in non-interactive WSL env)"
fi

echo "== 2. login-shell env (sources ~/.bashrc/~/.profile) =="
v=$(bash -lc 'printf %s "${ANTHROPIC_API_KEY:-}"' 2>/dev/null)
if [ -n "$v" ]; then echo "login-shell has it: ${v:0:12}... (len ${#v})"; else echo "login-shell: (NOT set)"; fi

echo "== 3. Secrets.txt (N3 check) =="
if [ -f "$SECRETS" ]; then
  if grep -iqE 'anthropic|api[_-]?key' "$SECRETS"; then
    echo "Secrets.txt HAS an anthropic/api_key line:"
    grep -inE 'anthropic|api[_-]?key' "$SECRETS" | sed -E 's/=(.{8}).*/=\1.../'
  else
    echo "(no anthropic/api_key entry in Secrets.txt yet)"
  fi
else
  echo "Secrets.txt not found at $SECRETS"
fi

echo "== 4. anthropic SDK availability (no network) =="
python3 -c "import anthropic, sys; print('anthropic SDK', anthropic.__version__)" 2>&1 || echo "anthropic SDK NOT importable (pip install anthropic needed)"
