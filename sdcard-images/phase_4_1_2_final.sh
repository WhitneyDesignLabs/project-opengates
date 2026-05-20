#!/bin/bash
# Phase 4.1.2 final: substitute HF placeholder in workspace README, land
# Step 9 consolidated handback, append worklog, commit the Step 7/8
# tooling scripts, push to origin/main.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw

git add \
  bench/fork/lora/hf-publish/README.md \
  sync/from_code.md \
  sync/to_code.md \
  sync/worklog.md \
  sdcard-images/phase_4_1_2_commit_followup.sh \
  sdcard-images/phase_4_1_2_fork_crlf.sh \
  sdcard-images/phase_4_1_2_hf_upload.py \
  sdcard-images/phase_4_1_2_tags.sh \
  sdcard-images/phase_4_1_2_worklog_append.sh \
  sdcard-images/phase_4_1_2_final.sh

echo "== secrets grep on staged diff (value-shape; non-md/non-txt) =="
SUSP=$(git diff --cached -- ':!*.md' ':!*.txt' ':!*.jsonl' ':!.gitignore' \
       | grep -nE '^\+' \
       | grep -inE '(\b[0-9]{8,12}:[A-Za-z0-9_-]{30,}|sk-ant-api[0-9a-z]{2}-[A-Za-z0-9_-]{40,}|sk-or-v1-[a-f0-9]{60,}|\bhf_[A-Za-z0-9]{30,}\b|-----BEGIN [A-Z ]*PRIVATE KEY-----|ssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{60,})' \
       || true)
if [ -n "$SUSP" ]; then
  echo "POTENTIAL SECRET VALUES:"; echo "$SUSP" | head -n 20
  exit 2
fi
echo "secrets-grep: clean."

git -c user.name="Scott Whitney" \
    -c user.email="scott@whitneydesignlabs.com" \
    -c commit.gpgsign=false \
    commit -m "$(cat <<'EOF'
phase 4.1.2 close: HF publication + tags + final handback

- bench/fork/lora/hf-publish/README.md: substitute <YOUR-HF-USER>
  placeholder with WhitneyDesignLabs so the workspace copy matches
  the live HF model card.
- sync/from_code.md: Step 9 consolidated handback — what shipped
  where (commit hashes, tag names, public URLs).
- sync/worklog.md: durable 2026-05-19 entry covering Phase 4.1.1
  corpus salvage + Phase 4.1.2 publication.
- sync/to_code.md: directive snapshot at close (HF setup confirmation
  + Step 3.5 follow-up authorization + workspace repo URL).
- sdcard-images/phase_4_1_2_*.{sh,py}: the Step 7/8 tooling actually
  used to land this phase — HF upload driver, tag push, worklog
  appender, fork CRLF cleanup, follow-up commit script.

Project Opengates v1.1 milestone published:
- Workspace: https://github.com/WhitneyDesignLabs/project-opengates-
  tag v1.1-milestone @ f79b2a4
- Firmware fork: https://github.com/WhitneyDesignLabs/WireClaw
  tag firmware-v0.4.1 @ bf80fa9
- Model: https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora

Code stops here per directive Step 9. Next phase is Cowork + Scott
big-picture review before authorizing v1.3 training.
EOF
)"

echo
echo "== pushing =="
git push origin main
echo
echo "== final HEAD =="
git log --oneline -6
