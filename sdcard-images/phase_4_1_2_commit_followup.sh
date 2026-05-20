#!/bin/bash
# Phase 4.1.2 Step 3.5 (Scott-approved follow-up): add project tooling
# code that was deliberately excluded from b3a5f50. Scope: bench/
# harness, lora extras the directive didn't list verbatim, training
# configs. Excludes training-data/*.jsonl (HF dataset path) and SD
# images. Secrets-grep again.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw

to_stage=(
  # bench/ harness — the benchmarking machinery
  bench/README.md
  bench/classify.py
  bench/report.py
  bench/run.py
  bench/serial_capture.py
  bench/wrap_up_classify.py
  bench/requirements.txt
  bench/test_cases.yaml

  # bench/wireclaw_data — bench fixtures (prompt variants + tool examples)
  bench/wireclaw_data/build_examples_tools.py
  bench/wireclaw_data/system_prompt_full.txt
  bench/wireclaw_data/system_prompt_p02redesign.txt
  bench/wireclaw_data/system_prompt_p02v2.txt
  bench/wireclaw_data/system_prompt_truncated.txt
  bench/wireclaw_data/tools_examples.json
  bench/wireclaw_data/tools_examples_selective.json
  bench/wireclaw_data/tools_stock.json

  # lora harness extras the original commit message named but the
  # explicit directive list omitted
  bench/fork/lora/aggregate_overnight.py
  bench/fork/lora/ollama_logging_proxy.py
  bench/fork/lora/tg_auth_bootstrap.py
  bench/fork/lora/train.py

  # training configs (small YAML)
  bench/fork/lora/training/configs/brev.yaml
  bench/fork/lora/training/configs/kscale.yaml

  # updated .gitignore (adds *.img, bench/results/, *.testmarker)
  .gitignore
)

echo "== staging =="
for f in "${to_stage[@]}"; do
  if [ -e "$f" ]; then
    git add -- "$f"
  else
    echo "MISSING (skipping): $f"
  fi
done

echo
echo "== secrets grep on staged diff (value-shape; non-md/non-txt) =="
SUSP=$(git diff --cached -- ':!*.md' ':!*.txt' ':!*.jsonl' ':!.gitignore' \
       | grep -nE '^\+' \
       | grep -inE '(\b[0-9]{8,12}:[A-Za-z0-9_-]{30,}|sk-ant-api[0-9a-z]{2}-[A-Za-z0-9_-]{40,}|sk-or-v1-[a-f0-9]{60,}|\bhf_[A-Za-z0-9]{30,}\b|-----BEGIN [A-Z ]*PRIVATE KEY-----|ssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{60,})' \
       || true)
if [ -n "$SUSP" ]; then
  echo "POTENTIAL SECRET VALUES FOUND:"
  echo "$SUSP" | head -n 40
  echo "ABORTING."
  exit 2
fi
echo "secrets-grep: clean."

BAD_FN=$(git diff --cached --name-only | grep -iE '^(Secrets\.txt|SetupBasics\.txt|.*\.env|.*_token.*)$' || true)
if [ -n "$BAD_FN" ]; then
  echo "FORBIDDEN FILE STAGED: $BAD_FN"
  exit 2
fi
echo "filename-blocklist: clean."

echo
echo "== staged inventory =="
git diff --cached --name-only
echo
git diff --cached --stat | tail -n 5

echo
echo "== committing =="
git commit -m "$(cat <<'EOF'
phase 4.1.2 follow-up: add project tooling code (bench harness, lora training pipeline, proxy, helpers)

Scott-approved follow-up to b3a5f50. Adds the project's tooling code
that the original consolidated commit deliberately omitted (the
directive's stage list focused on docs + the harness files specifically
named in the commit message). This brings the published repo's code
surface up to a self-contained, reproducible state.

Added:
- bench/ : the full benchmarking harness (README, classify.py, report.py,
  run.py, serial_capture.py, wrap_up_classify.py, requirements.txt,
  test_cases.yaml)
- bench/wireclaw_data/ : bench fixtures — prompt variants
  (full / p02redesign / p02v2 / truncated) and tool example sets
  (stock / examples / examples_selective) + build_examples_tools.py
- bench/fork/lora/ : the lora-side helpers not listed in the prior
  stage but referenced throughout — aggregate_overnight.py,
  ollama_logging_proxy.py, tg_auth_bootstrap.py, train.py
- bench/fork/lora/training/configs/ : Brev + k-scale training configs

Updated .gitignore: exclude *.img (multi-GB SD images), /bench/results/
(bench run outputs), *.testmarker.

Not in this commit (deliberate):
- bench/fork/lora/training-data/*.jsonl (corpus → HuggingFace dataset)
- SD card images at sdcard-images/*.img (regenerable, too large for git)
- bench/results/ (run outputs)
EOF
)"

echo
echo "== result =="
git log --oneline -5
