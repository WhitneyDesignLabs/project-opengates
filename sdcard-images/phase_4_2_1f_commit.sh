#!/bin/bash
# Phase 4.2.1.F Steps 4-6: append worklog, stage workspace files, commit
# signed Scott with directive's message, push origin/main, tag
# v1.3-release annotated, push tag.
set -u
ROOT=/mnt/c/Users/homet/Documents/WireClaw
WL=$ROOT/sync/worklog.md

# --- worklog append ---
cat >> "$WL" <<'WORKLOG'


## 2026-05-20 — Phase 4.2.1.F v1.3 partial-ship publication

**The day in one line:** Published `wireclaw-agent:v1.3` as a discrete HuggingFace release with the wins documented and the two known regressions honestly disclosed; v1.1 remains chip production until `v1.3.1` lands.

**Wins shipped:**
- Constitutional eval default-temp pass rate: 43.3% → **70.0%** (+27pp)
- Article-citation rate on refusals: 52% → **92%** (default), 60% → **96%** (temp=0)
- Roleplay-jailbreak (`deception_04_roleplay_unrestricted`) — v1.1's most concerning default-temp failure — **resolved at both temperatures with explicit Article 19 citation**
- Variance gap collapsed: default-temp behavior now matches greedy decoding

**Known regressions disclosed (v1.3.1 targets):**
- Harm-category article specificity (default temp, −2 prompts): refusal behavior preserved on both — model still refuses — but article citation shifted from specific (Article 3 Non-Weaponization) to generic (Article 19 Refusal). Behavioral safety unchanged; citation specificity regressed.
- Truth/uncertainty over-refusal (temp=0, 4/4 → 0/4): model now treats calibrated-uncertainty prompts as refusals. The 4.2.1.A synthetic data framed honest-hedging too close to refusal patterns. v1.3.1 targets this with revised hedging-distinct-from-refusal examples.

**Partial-ship rationale:** wins are structural and large (article-citation discipline locked in, roleplay-jailbreak resolved, default-temp pass +27pp), regressions are bounded and diagnosable. v1.3.1 expected sub-week turnaround. Chip production stays on v1.1 until v1.3.1 ships a clean eval (no >1-prompt category regressions).

**Spend recap (Phase 4.2.1 total):**
- Sonnet synthetic generation (4.2.1.A): $0.49
- Brev H100 training + prep (4.2.1.C): ~$5.20 (47 min train wall + 1.5h prep at $2.28/hr)
- Haiku eval judging (4.2.1.D, both temps + smoke): ~$0.10
- **Phase 4.2.1 total: ~$5.80** (within directive's $5–10 ceiling)

**Links:**
- HF v1.3: https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.3-lora
- HF v1.1 (chip production): https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora
- v1.3 vs v1.1 comparison: `bench/fork/lora/eval/constitutional_eval/results/v1.3-vs-v1.1.md`
- Constitution canonical: https://clawhub.ai/souls/opengates-constitution

### Tag

"2026-05-20 — Phase 4.2.1.F close: v1.3 partial-ship published to HF (wireclaw-agent-v1.3-lora); workspace tagged v1.3-release; v1.1 remains chip production; v1.3.1 patch queued for harm citation-specificity + truth/uncertainty over-refusal."
WORKLOG
echo "worklog appended"

cd "$ROOT"

# --- stage ---
git add \
  PROJECT_STATUS.md \
  bench/fork/lora/hf-publish/v1.3-README.md \
  bench/fork/lora/eval/constitutional_eval/results/v1.3-vs-v1.1.md \
  bench/fork/lora/eval/constitutional_eval/results/v1.3-default.jsonl \
  bench/fork/lora/eval/constitutional_eval/results/v1.3-default.md \
  bench/fork/lora/eval/constitutional_eval/results/v1.3-temp0.jsonl \
  bench/fork/lora/eval/constitutional_eval/results/v1.3-temp0.md \
  bench/fork/lora/training-data/v1.3-synthetic.jsonl \
  bench/fork/lora/training-data/v1.3-train.manifest.md \
  bench/fork/lora/training/wireclaw-agent-v1.3.Modelfile.template \
  bench/fork/lora/training/configs/brev-v1.3.yaml \
  sdcard-images/phase_4_2_1a_synth.py \
  sdcard-images/phase_4_2_1a_inspect.py \
  sdcard-images/phase_4_2_1a_run.sh \
  sdcard-images/phase_4_2_1b_assemble.py \
  sdcard-images/phase_4_2_1c_brev.sh \
  sdcard-images/phase_4_2_1c_fix_deps.sh \
  sdcard-images/phase_4_2_1c_watch.sh \
  sdcard-images/phase_4_2_1d_build.sh \
  sdcard-images/phase_4_2_1d_download.sh \
  sdcard-images/phase_4_2_1d_smoke.py \
  sdcard-images/phase_4_2_1d_run_smoke.sh \
  sdcard-images/phase_4_2_1d_run_eval.sh \
  sdcard-images/phase_4_2_1d_compare.py \
  sdcard-images/phase_4_2_1f_hf_upload.py \
  sdcard-images/phase_4_2_1f_commit.sh \
  sync/worklog.md \
  sync/to_code.md \
  sync/from_code.md

echo "== staged =="
git diff --cached --name-only

echo
SUSP=$(git diff --cached -- ':!*.md' ':!*.txt' ':!*.jsonl' ':!.gitignore' \
       | grep -nE '^\+' \
       | grep -inE '(\b[0-9]{8,12}:[A-Za-z0-9_-]{30,}|sk-ant-api[0-9a-z]{2}-[A-Za-z0-9_-]{40,}|sk-or-v1-[a-f0-9]{60,}|\bhf_[A-Za-z0-9]{30,}\b|-----BEGIN [A-Z ]*PRIVATE KEY-----|ssh-(rsa|ed25519) AAAA[A-Za-z0-9+/=]{60,})' \
       || true)
[ -z "$SUSP" ] && echo "secrets-grep: clean." || { echo "SECRETS:"; echo "$SUSP"; exit 2; }
BAD_FN=$(git diff --cached --name-only | grep -iE '^(Secrets\.txt|SetupBasics\.txt|.*\.env|.*_token.*)$' || true)
[ -z "$BAD_FN" ] && echo "filename-blocklist: clean." || { echo "FORBIDDEN: $BAD_FN"; exit 2; }

# --- commit ---
git -c user.name="Scott Whitney" \
    -c user.email="scott@whitneydesignlabs.com" \
    -c commit.gpgsign=false \
    commit -m "$(cat <<'EOF'
phase 4.2.1: v1.3 partial-ship — constitutional refusal robustness + article-citation discipline

v1.3 LoRA adapter published as a discrete release. v1.1 remains chip
production until v1.3.1 lands (in progress).

Wins:
- Article-citation rate 52%->92% (default), 60%->96% (temp=0)
- Default-temp pass 43.3%->70.0% (+27pp)
- Roleplay-jailbreak resolved at both temperatures
- Variance gap collapsed (default matches greedy)

Known regressions (v1.3.1 targets):
- Harm category: refusal preserved, citation specificity regressed
  (Article 19 default vs Article 3 specific). Behavioral safety unchanged.
- Truth/uncertainty temp=0: 4/4 -> 0/4 (over-refusal on honest-hedging
  prompts that should receive calibrated answers)

HuggingFace: https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.3-lora
Constitution canonical: https://clawhub.ai/souls/opengates-constitution

Phase 4.2.1.F close. Phase 4.2.1.G (v1.3.1 patch) next.
EOF
)"

echo
echo "== push =="
git push origin main 2>&1 | tail -n 5

echo
echo "== tag v1.3-release =="
HASH=$(git rev-parse HEAD)
git -c user.name="Scott Whitney" -c user.email="scott@whitneydesignlabs.com" \
    tag -a v1.3-release -m "v1.3 partial-ship release — constitutional refusal robustness + article-citation discipline

Constitutional eval n=30:
- Default-temp pass 43.3%->70.0% (+27pp vs v1.1)
- Article-citation rate 52%->92% (default), 60%->96% (temp=0)
- Roleplay-jailbreak (deception_04) resolved at both temperatures

Known regressions (v1.3.1 targets):
- harm category citation-specificity (default -2; refusal preserved)
- truth/uncertainty over-refusal (temp=0, 4/4->0/4)

v1.1 remains chip production. HF: WhitneyDesignLabs/wireclaw-agent-v1.3-lora" "$HASH"

git push origin v1.3-release 2>&1 | tail -n 3

echo
echo "== result =="
git log --oneline -3
git tag -l | grep v1.3
