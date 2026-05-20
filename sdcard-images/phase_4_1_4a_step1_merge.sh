#!/bin/bash
# Phase 4.1.4a Step 1: merge docs-canonical-soul-url into wdl-v1 on the
# WireClaw fork. --no-ff so the merge commit is preserved. Signed Scott.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw-fork
echo "== before =="
git status -sb
git log --oneline -3
echo
echo "== fetch + checkout wdl-v1 =="
git fetch origin 2>&1 | tail -n 5
git checkout wdl-v1
git pull --ff-only origin wdl-v1 2>&1 | tail -n 3
echo
echo "== merge =="
git -c user.name="Scott Whitney" \
    -c user.email="scott@whitneydesignlabs.com" \
    -c commit.gpgsign=false \
    merge --no-ff origin/docs-canonical-soul-url -m "$(cat <<'EOF'
Merge branch 'docs-canonical-soul-url' into wdl-v1

Adds the canonical Project Opengates Constitution URL anchor to
README-WhitneyDesignLabs.md so the binding constitutional text is
discoverable from the fork's default branch.
EOF
)"
echo
echo "== push =="
git push origin wdl-v1 2>&1 | tail -n 5
echo
echo "== result =="
git log --oneline -4
