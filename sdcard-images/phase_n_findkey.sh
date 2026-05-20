#!/bin/bash
set -u
S="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
echo "== bytes/lines =="; wc -lc "$S"
echo "== lines mentioning anthropic/api/sk-ant (values masked) =="
grep -inE 'anthropic|api[_-]?key|sk-ant' "$S" \
  | sed -E 's/(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]*/\1***MASKED***/g; s/(:[^:=]*=.{6}).*/\1***/'
echo "== tail 8 (masked) =="
tail -8 "$S" | sed -E 's/(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]*/\1***MASKED***/g; s/(=.{4}).*/\1***/'
