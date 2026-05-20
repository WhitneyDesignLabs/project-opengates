#!/bin/bash
# Phase 4.1.2 Step 3: workspace milestone commit. Initializes the repo
# (Scott authorized), stages the directive's file list verbatim plus a
# few harness code files the commit message names (persona_runner.py /
# merge_corpus.py / overnight_capture.sh), runs a secrets grep on the
# staged diff, commits signed Scott Whitney. Does NOT push.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw

# 1. Init if needed
if [ ! -d .git ]; then
  git init -b main
  echo "INIT-OK"
fi

# Configure local commit identity (workspace-local, not global).
git config user.name  "Scott Whitney"
git config user.email "scott@whitneydesignlabs.com"
git config commit.gpgsign false

# 2. Stage files per directive (+ obvious code deps the commit message names)
to_stage=(
  CLAUDE.md
  PROJECT_STATUS.md
  SOUL.md
  OPEN_QUESTIONS.md
  baking-constitutional-models-8gb-vram.md
  .gitignore
  sync/worklog.md
  sync/to_code.md
  sync/from_code.md
  sync/queued_p05_upstream.md
  sync/drafts/p01_gh_commands.md
  sync/drafts/p01_issue.md
  sync/drafts/p01_pr.md
  sync/drafts/p05_gh_commands.md
  sync/drafts/p05_issue.md
  sync/drafts/p05_pr.md
  bench/fork/PATCHES.md
  bench/fork/HANDOFF.md
  bench/fork/patches/F01-ollama-defensive-opts.md
  bench/fork/patches/P01-text-leak-detector.md
  bench/fork/patches/P02-prompt-truncation-fix.md
  bench/fork/patches/P03-example-augmented-tools.md
  bench/fork/patches/P04-led-vocab-disambiguation.md
  bench/fork/patches/P05-serial-send-description.md
  bench/fork/patches/P06-config-wiring.md
  bench/fork/patches/P08-config-write-side.md
  bench/fork/patches/P09-file-tool-buffer-caps.md
  bench/fork/patches/P10-strict-numeric-arg-parsing.md
  bench/fork/patches/P11-use-modelfile-system.md
  bench/fork/bake/PLAN.md
  bench/fork/bake/BUILD-LOG.md
  bench/fork/bake/wireclaw-agent-v1.Modelfile
  bench/fork/lora/PHASE3.md
  bench/fork/lora/RIG.md
  bench/fork/lora/CORPUS_CAPTURE.md
  bench/fork/lora/SDCARD_PROVISIONING.md
  bench/fork/lora/PHASE3.0-wrap-up-classifier.md
  bench/fork/lora/training-data/constitution/SOUL.md
  bench/fork/lora/training-data/constitution/SOUL-LOCAL.md
  bench/fork/lora/training-data/constitution/SOUL-CHIP.md
  bench/fork/lora/training/BREV_RUNBOOK.md
  bench/fork/lora/training/BREV_GOTCHAS.md
  bench/fork/lora/training/smoke_test.py
  bench/fork/lora/training/wireclaw-agent-v1.1.Modelfile.template
  bench/fork/lora/corpus-labels/3.1.3-handlabel-PRIORITY.md
  bench/fork/lora/corpus-labels/3.1.3-handlabel-sample-v1-BLIND.md
  bench/fork/lora/corpus-labels/3.1.3-handlabel-sample-v1.md
  bench/fork/lora/corpus-labels/COWORK_LABELS_REPORT.md
  bench/fork/lora/corpus-labels/HANDLABEL_GUIDE.md
  bench/fork/lora/personas/persona_01_basic.py
  bench/fork/lora/personas/persona_02_power_user.py
  bench/fork/lora/personas/persona_03_ambiguity_tester.py
  bench/fork/lora/personas/persona_04_memory_specialist.py
  bench/fork/lora/personas/persona_05_automation_operator.py
  bench/fork/lora/personas/persona_06_robotics_motion.py
  bench/fork/lora/personas/persona_07_sensor_telemetry.py
  bench/fork/lora/corpus/MANIFEST.md
  bench/fork/lora/corpus/v1.1-overnight-2026-05-18.REPAIRED.sample.jsonl
  bench/fork/lora/corpus/quarantine/README.md
  bench/fork/lora/corpus/quarantine/v1.1-overnight-2026-05-18.SCRAMBLED.jsonl
  bench/fork/lora/hf-publish/README.md
  bench/fork/lora/persona_runner.py
  bench/fork/lora/merge_corpus.py
  bench/fork/lora/overnight_capture.sh
)

echo "== staging =="
for f in "${to_stage[@]}"; do
  if [ -e "$f" ]; then
    git add -- "$f"
  else
    echo "MISSING (skipping): $f"
  fi
done

# Also stage every helper script
git add -- 'sdcard-images/*.sh' 'sdcard-images/*.py' 2>/dev/null

echo
echo "== secrets grep on staged diff =="
# Match REAL credential VALUES, not prose discussing the existence of secrets.
# Look only at +lines (added) and only patterns that resemble actual tokens.
SUSP=$(git diff --cached -- ':!*.md' ':!*.txt' ':!*.jsonl' ':!.gitignore' \
       | grep -nE '^\+' \
       | grep -inE '(\b[0-9]{8,12}:[A-Za-z0-9_-]{30,}\b|sk-ant-api[0-9a-z]{2}-[A-Za-z0-9_-]{40,}|sk-or-v1-[a-f0-9]{60,}|\bhf_[A-Za-z0-9]{30,}\b|-----BEGIN [A-Z ]*PRIVATE KEY-----|ssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{60,})' \
       || true)
if [ -n "$SUSP" ]; then
  echo "POTENTIAL SECRET VALUES FOUND IN STAGED DIFF (non-md/non-txt):"
  echo "$SUSP" | head -n 40
  echo "ABORTING — review before commit."
  exit 2
fi
echo "secrets-grep (value-shape match on non-md/non-txt): clean."

# Extra belt: explicit filename check — guarantee Secrets.txt / SetupBasics.txt / .env never staged.
BAD_FN=$(git diff --cached --name-only | grep -iE '^(Secrets\.txt|SetupBasics\.txt|.*\.env|.*_token.*)$' || true)
if [ -n "$BAD_FN" ]; then
  echo "FORBIDDEN FILE STAGED: $BAD_FN"
  exit 2
fi
echo "filename-blocklist: clean."

echo
echo "== staged inventory =="
echo -n "files staged: "; git diff --cached --name-only | wc -l
git diff --cached --stat | tail -n 5

# 3. Commit
git commit -m "$(cat <<'EOF'
phase 4.0.x → 4.1.x: project milestone — fleet recovery, protocol artifact, first stable v1.1 overnight, corpus pairing fix

This is the consolidated workspace commit covering the Phase 4 fleet-recovery
work. Firmware fixes already shipped separately to WireClaw-fork (bf80fa9).

Phase 4.0.x — Fleet recovery:
- Diagnosed and fixed three concurrent firmware issues: unvalidated gpio_write
  to ESP32-C6 reserved pins, Telegram offset crash-replay loop, rulesSave OOB
  write. All three landed in WireClaw-fork@bf80fa9.
- c6-02 + c6-03 reflashed and validated: emergency_stop persona prompt
  (deterministic fleet-killer two nights prior) survived 42/42 firings on
  the patched firmware.

Phase 4.1.x — Corpus capture stabilization:
- First successful 11-hour overnight capture: pi02+pi03, full 7-persona
  rotation with safe-pin-remapped personas, graceful auto-stop. 3,030 turns
  captured, 1 boot-banner in 3,030 — essentially 100% chip stability.
- Discovered + diagnosed + fixed a harness pairing bug in persona_runner.py
  (Telethon FIFO race under load — settled-collect + plumbing filter fix).
  Recovered pairing from 14%-on-topic to 95-100%.

Project artifacts:
- CLAUDE.md: project-level protocol for agent-to-agent workflows
  (three-actor distinction, communication via file channel, L0-L4
  authorization tiers, recurring failure modes consolidated)
- SOUL.md: 26-article constitution (canonical)
- Persona safe-pin remap: persona_02/05/06 remapped off ESP32-C6 reserved
  pins (12, 13, 24-30) to safe range (0-11, 14-23), intent preserved.
EOF
)"
echo
echo "== commit hash =="
git log --oneline -1
echo
echo "DONE. No push performed (Step 4 gated on Scott confirmation)."
