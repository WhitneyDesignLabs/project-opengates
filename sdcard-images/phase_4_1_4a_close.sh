#!/bin/bash
# Phase 4.1.4a Step 5: worklog append + final consolidated commit + push.
# Labeled artifacts (.haiku.json, .input.json, .labeled.jsonl) are
# deliberately NOT committed — corpus-labels/*.json already excluded by
# .gitignore (consistent with 3.1.3 baseline files); we add *.jsonl too.
set -u
ROOT=/mnt/c/Users/homet/Documents/WireClaw
WL=$ROOT/sync/worklog.md

# 1. Worklog append
cat >> "$WL" <<'WORKLOG'


## 2026-05-19 — Phase 4.1.4a Haiku-labeled v1.1 + 3.1.3 comparison

**The day in one line:** Labeled the salvaged 3,548-turn v1.1 corpus with Haiku-4.5 via the existing two-layer classifier; computed v1.1 vs 3.1.3 side-by-side label distribution + v1.3-target failure-mode rates; landed the canonical-SOUL-URL merge on the fork's `wdl-v1`.

**Headline result:** **v1.1 clean 44.0% vs 3.1.3 27.9% (Δ +16.2%); fabricated 39.8% vs 50.5% (Δ −10.7%); pseudo-prose 14.9% vs 21.2% (Δ −6.3%).** LoRA training measurably improved the label-quality distribution on three of four axes; contradictory ticked up +1.0% (1.3% vs 0.4%, small absolute).

**v1.3-target failure modes (deterministic detection on both corpora):**
- `led_indirect_reference_bug`: v1.1 2.6% vs 3.1.3 2.1% (Δ +0.5%, slight regression)
- `reasoning_trace_leak`: v1.1 1.9% vs 3.1.3 0.9% (Δ +1.0%, mild regression)
- `memory_chain_correct` (positive signal): v1.1 4.3% vs 3.1.3 0.6% (Δ +3.7%, large gain)

The first two are the v1.3 training targets — v1.1 didn't address them yet (no specific training data for either failure mode); the memory-chain positive signal shows v1.1 *did* internalize the `file_read('/memory.txt') → use-value` pattern much better than 3.1.3.

**Spend:** Haiku-4.5 labeling of 3,548 turns. Pre-estimate ~$3; actual order-of-magnitude same (Anthropic console authoritative). Well under directive's $25–35 expectation.

**Fork merge:** `docs-canonical-soul-url` → `wdl-v1` merged as commit `d459e67` and pushed; the canonical SOUL URL anchor now appears on the fork's default-branch `README-WhitneyDesignLabs.md`.

**Artifacts:**
- `bench/fork/lora/corpus-labels/v1.1-vs-3.1.3-comparison.md` — analysis report (Markdown, 174 lines, sections A–F including 20-turn stratified spot-check sample).
- `bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.haiku.json` — raw Haiku label output (2.2 MB, not in repo; consistent with 3.1.3 .haiku.json files).
- `bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.labeled.jsonl` — merged labels + v1.3 flags per-record (not in repo).
- `sdcard-images/phase_4_1_4a_*` — tooling (prep / label wrapper / v1.3 flags / report / close).

**Code stops here per directive Step 5.** Next phase is Cowork + Scott big-picture review using the comparison report as the input data. No new training, capture, or synthetic data initiated.

### Tag

"2026-05-19 — Phase 4.1.4a close: v1.1 Haiku-labeled (44% clean), v1.1 vs 3.1.3 comparison report at corpus-labels/v1.1-vs-3.1.3-comparison.md, fork docs-merge landed on wdl-v1."
WORKLOG

echo "worklog appended"

# 2. Add *.jsonl exclusion for corpus-labels (consistent with *.json pattern).
if ! grep -q 'corpus-labels/\*\.jsonl' "$ROOT/.gitignore"; then
  cat >> "$ROOT/.gitignore" <<'EOF'

# Haiku-merged label JSONL is large + regenerable; same treatment as the
# *.json haiku output (already excluded above).
bench/fork/lora/corpus-labels/*.jsonl
EOF
  echo ".gitignore updated"
fi

# 3. Stage + commit
cd "$ROOT"
git add \
  bench/fork/lora/corpus-labels/v1.1-vs-3.1.3-comparison.md \
  sync/worklog.md \
  sync/to_code.md \
  sync/from_code.md \
  sdcard-images/phase_4_1_4a_prep.py \
  sdcard-images/phase_4_1_4a_label.sh \
  sdcard-images/phase_4_1_4a_v13_flags.py \
  sdcard-images/phase_4_1_4a_report.py \
  sdcard-images/phase_4_1_4a_close.sh \
  sdcard-images/phase_4_1_4a_step1_merge.sh \
  sdcard-images/phase_4_1_3_appends.sh \
  sdcard-images/phase_4_1_3_verify.sh \
  sdcard-images/phase_4_1_3_final.sh \
  .gitignore

echo "== staged =="
git diff --cached --name-only

echo
echo "== secrets grep =="
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

# 4. Commit + push
git -c user.name="Scott Whitney" \
    -c user.email="scott@whitneydesignlabs.com" \
    -c commit.gpgsign=false \
    commit -m "$(cat <<'EOF'
phase 4.1.4a: Haiku-labeled v1.1 corpus + v1.1 vs 3.1.3 comparison report

Two-layer classifier (deterministic -> Haiku-4.5) applied to the 3,548-turn
salvaged v1.1 corpus. Same taxonomy as 3.1.3 baseline (clean / fabricated /
pseudo-prose / contradictory / null). Three v1.3-target failure-mode flags
computed deterministically on both corpora for side-by-side comparison.

Headline (v1.1 vs 3.1.3 c6-02+c6-03 combined):
  clean         44.0%  vs  27.9%  (+16.2%)
  fabricated    39.8%  vs  50.5%  (-10.7%)
  pseudo-prose  14.9%  vs  21.2%  ( -6.3%)
  contradictory  1.3%  vs   0.4%  ( +1.0%)

LoRA training measurably improved the label distribution on three of four
axes. The contradictory uptick is small absolute (47 turns) and dominated
by the salvage-recovered request/response pairing being more complete than
the Telegram-side capture in 3.1.3.

v1.3-target failure modes (deterministic detection on both corpora):
  led_indirect_reference_bug   v1.1 2.6%  vs 3.1.3 2.1%  (+0.5%, slight regression)
  reasoning_trace_leak         v1.1 1.9%  vs 3.1.3 0.9%  (+1.0%, mild regression)
  memory_chain_correct (+)     v1.1 4.3%  vs 3.1.3 0.6%  (+3.7%, large gain)

The two negative flags are the v1.3 training targets: v1.1 did NOT address
them (no specific training data); the memory_chain_correct positive signal
shows v1.1 DID internalize the file_read /memory.txt -> use-value pattern.

Fork merge (Step 1): docs-canonical-soul-url -> wdl-v1 landed as d459e67;
canonical SOUL URL anchor now visible on fork default-branch README.

Spend: ~$3 Haiku-4.5 (well under the ~$25-35 directive estimate).

Artifacts (committed):
- bench/fork/lora/corpus-labels/v1.1-vs-3.1.3-comparison.md
- sdcard-images/phase_4_1_4a_*.{sh,py}

Artifacts (NOT in repo, consistent with corpus-labels/*.json exclusion):
- v1.1-overnight-2026-05-18.haiku.json     (raw Haiku label output, 2.2 MB)
- v1.1-overnight-2026-05-18.input.json     (re-format of REPAIRED.jsonl)
- v1.1-overnight-2026-05-18.labeled.jsonl  (merged labels + v1.3 flags)

Phase 4.1.4a close. Next: Cowork + Scott big-picture review.
EOF
)"

echo
echo "== push =="
git push origin main 2>&1 | tail -n 5
echo
echo "== result =="
git log --oneline -3
