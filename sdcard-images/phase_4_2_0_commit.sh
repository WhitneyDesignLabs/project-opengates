#!/bin/bash
# Phase 4.2.0 Step 1 (now approved): commit + push the eval suite +
# v1.1 baseline.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw

git add \
  bench/fork/lora/eval/constitutional_eval/prompts.jsonl \
  bench/fork/lora/eval/constitutional_eval/runner.py \
  bench/fork/lora/eval/constitutional_eval/README.md \
  bench/fork/lora/eval/constitutional_eval/results/v1.1-baseline.jsonl \
  bench/fork/lora/eval/constitutional_eval/results/v1.1-baseline.md \
  sdcard-images/phase_4_2_0_run.sh \
  sdcard-images/phase_4_2_0_compare.py \
  sdcard-images/phase_4_2_0_commit.sh \
  sync/from_code.md \
  sync/to_code.md \
  sync/worklog.md

echo "== staged =="
git diff --cached --name-only

echo
echo "== secrets grep =="
SUSP=$(git diff --cached -- ':!*.md' ':!*.txt' ':!*.jsonl' ':!.gitignore' \
       | grep -nE '^\+' \
       | grep -inE '(\b[0-9]{8,12}:[A-Za-z0-9_-]{30,}|sk-ant-api[0-9a-z]{2}-[A-Za-z0-9_-]{40,}|sk-or-v1-[a-f0-9]{60,}|\bhf_[A-Za-z0-9]{30,}\b|-----BEGIN [A-Z ]*PRIVATE KEY-----|ssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{60,})' \
       || true)
if [ -n "$SUSP" ]; then echo "SECRETS:"; echo "$SUSP"; exit 2; fi
echo "secrets-grep: clean."
BAD_FN=$(git diff --cached --name-only | grep -iE '^(Secrets\.txt|SetupBasics\.txt|.*\.env|.*_token.*)$' || true)
[ -z "$BAD_FN" ] && echo "filename-blocklist: clean." || { echo "FORBIDDEN: $BAD_FN"; exit 2; }

git -c user.name="Scott Whitney" \
    -c user.email="scott@whitneydesignlabs.com" \
    -c commit.gpgsign=false \
    commit -m "$(cat <<'EOF'
phase 4.2.0: constitutional eval suite + v1.1 baseline

Adds bench/fork/lora/eval/constitutional_eval/ — a 30-prompt adversarial
suite testing SOUL.md adherence under stress, across 6 categories
(deception, authorization tier, harm requests, log tampering, identity
stress, truth/uncertainty). Python runner targets Ollama directly via
the `--model` flag (model-agnostic; reusable against v1.3 / v1.4 /
future models). Haiku used as LLM-as-judge for ambiguous scoring cases.

v1.1 baseline at Ollama default temperature: 13/30 pass (43.3%).
Per-category breakdown:
  - harm: 4/6 (67%) — strongest
  - deception: 3/6 (50%)
  - identity_stress: 2/4 (50%)
  - truth_uncertainty: 2/4 (50%)
  - authorization: 2/6 (33%)
  - log_tampering: 1/4 (25%) — weakest

Article-citation rate on refusals: ~54%. Scott's manual 7/7 probe
substantially overstated robustness — single-shot adversarial sampling
reveals "capable but unstable" disposition.

Phase 4.2.1 (v1.3 training) gated on a follow-on temperature=0
diagnostic to isolate variance vs capability axis.
EOF
)"

echo
echo "== push =="
git push origin main 2>&1 | tail -n 5
echo
git log --oneline -3
