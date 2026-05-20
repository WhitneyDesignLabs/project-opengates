#!/bin/bash
# Phase 4.1.3 Step 1 + Step 7: update remote, secrets-grep, consolidated
# commit covering Steps 2-6, push to renamed origin, annotated tag.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw

echo "== Step 1: remote set-url =="
git remote set-url origin https://github.com/WhitneyDesignLabs/project-opengates.git
git remote -v
git fetch origin 2>&1 | tail -n 5

echo
echo "== staging Step 2-6 changes =="
git add \
  README.md \
  SOUL.md \
  CLAUDE.md \
  PROJECT_STATUS.md \
  bench/fork/lora/hf-publish/README.md \
  sync/worklog.md \
  sync/to_code.md \
  sync/from_code.md \
  OPEN_QUESTIONS.md \
  sdcard-images/phase_4_1_3_appends.sh \
  sdcard-images/phase_4_1_3_final.sh

echo
echo "== staged list =="
git diff --cached --name-only

echo
echo "== secrets grep (value-shape; non-md/non-txt) =="
SUSP=$(git diff --cached -- ':!*.md' ':!*.txt' ':!*.jsonl' ':!.gitignore' \
       | grep -nE '^\+' \
       | grep -inE '(\b[0-9]{8,12}:[A-Za-z0-9_-]{30,}|sk-ant-api[0-9a-z]{2}-[A-Za-z0-9_-]{40,}|sk-or-v1-[a-f0-9]{60,}|\bhf_[A-Za-z0-9]{30,}\b|-----BEGIN [A-Z ]*PRIVATE KEY-----|ssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{60,})' \
       || true)
if [ -n "$SUSP" ]; then
  echo "SECRETS:"; echo "$SUSP"; exit 2
fi
echo "secrets-grep: clean."
BAD_FN=$(git diff --cached --name-only | grep -iE '^(Secrets\.txt|SetupBasics\.txt|.*\.env|.*_token.*)$' || true)
[ -z "$BAD_FN" ] && echo "filename-blocklist: clean." || { echo "FORBIDDEN: $BAD_FN"; exit 2; }

echo
echo "== commit =="
git -c user.name="Scott Whitney" \
    -c user.email="scott@whitneydesignlabs.com" \
    -c commit.gpgsign=false \
    commit -m "$(cat <<'EOF'
phase 4.1.3: canonical SOUL URL discoverability + repo rename

Make https://clawhub.ai/souls/opengates-constitution the discoverable
canonical reference everywhere SOUL.md is referenced. Goal: downstream
humans + agents shouldn't have to hunt for the binding constitutional
text — it lives at one URL, every project artifact links to it.

Changes:
- HuggingFace model card (bench/fork/lora/hf-publish/README.md):
  Constitution section restructured with canonical URL + v0.2.0;
  Out-of-scope use uses explicit article-citation links to the
  canonical; License section cross-references the canonical
  alongside Llama 3.1 Community.
- Workspace README.md (NEW): landing page with canonical URL, project
  links (firmware fork + HF model + SOUL.md), state pointer, file
  index, Built-with-Llama attribution.
- SOUL.md: top-of-file canonical anchor block prepended (article
  content untouched per directive constraint).
- CLAUDE.md: Constitution section anchored on the canonical URL.
- WireClaw fork README-WhitneyDesignLabs.md: Constitutional Framework
  section with canonical URL (separate fork commit 54d6cea on branch
  docs-canonical-soul-url).
- PROJECT_STATUS.md: canonical-URL line at the top of Current state
  pointer.
- OPEN_QUESTIONS.md: long-term canonical hierarchy queued for
  Phase 4.1.4 (projectopengates.org publication).

SOUL-LOCAL.md and SOUL-CHIP.md verified to already reference the
canonical URL in their headers; left untouched as as-trained artifacts
(model trained on these exact bytes; the `www.` prefix is functionally
equivalent to no-www and not worth a training-data drift).

Repo rename: project-opengates- -> project-opengates (trailing-dash
typo cleanup). Local origin URL updated. GitHub auto-redirects old
URL for ~90 days.

Phase 4.1.3 close.
EOF
)"

echo
echo "== push =="
git push origin main 2>&1 | tail -n 8

echo
echo "== tag v1.1-milestone-canonical-url =="
HASH=$(git rev-parse HEAD)
git -c user.name="Scott Whitney" -c user.email="scott@whitneydesignlabs.com" \
    tag -a v1.1-milestone-canonical-url -m "Phase 4.1.3 close — canonical SOUL URL discoverability landed.

Every public artifact now links to https://clawhub.ai/souls/opengates-constitution.
Workspace repo renamed off the trailing-dash typo (project-opengates- -> project-opengates).
Fork branch docs-canonical-soul-url adds the same anchor to README-WhitneyDesignLabs.md.

Cumulative with v1.1-milestone (Phase 4.1.2 publication)." "$HASH"
git push origin v1.1-milestone-canonical-url 2>&1 | tail -n 5

echo
echo "== result =="
git log --oneline -3
git tag -l | grep canonical
