# Instructions for Claude Code

## STATUS: ACTIVE TASK — Phase 4.1.2 — Housekeeping: GitHub publication + HuggingFace model release

**Context:** Phase 4.1.1 corpus salvage (Path A) is approved and may be in flight or complete. This directive is the *next* phase after salvage lands. **Order of operations:**

1. If salvage is still running: finish it first, file the recovered-corpus stats handback, THEN proceed to Phase 4.1.2 below.
2. If salvage is complete: proceed to Phase 4.1.2 immediately.

Scott has called this a major milestone and wants the project's achievements preserved publicly (GitHub + HuggingFace) BEFORE the next training round. After this phase, Cowork + Scott will do a separate big-picture goal/metrics review before authorizing the next training round.

**Do NOT initiate Haiku labeling, v1.3 training, or any new capture round in this directive.** Those are post-housekeeping.

---

## Step 1 — PROJECT_STATUS.md rewrite

`PROJECT_STATUS.md` at workspace root was last updated 2026-05-12. Six days stale — currently describes the Phase 1 bisection era. Rewrite it to reflect the actual current state. New content should cover:

- Current model version (`wireclaw-agent:v1.1` deployed on azza, v1.2 trained but not deployed-as-production)
- Firmware version (`wdl-v1` branch, commit `bf80fa9`, three-fix release covering pin guard / Telegram offset persistence / rulesSave OOB)
- Fleet state (c6-02 + c6-03 production, c6-01 deferred to Phase 4.0.5, c6-pilot dead)
- Phase 4.0.x summary: post-mortem → reserved-pin + Telegram-redelivery root cause → fix + flash + validation (42/42 emergency_stop survival, 1 banner in 3,030 turns)
- Phase 4.1.x summary: first stable overnight capture, harness pairing bug surfaced + diagnosed + fixed, corpus salvage path
- Outstanding queued work: 4.0.4 firmware hardening, 4.0.5 c6-01 reflash, v1.3 training (gated on labeled clean corpus), broader fleet expansion
- Known v1.1 residuals to target in v1.3: indirect-reference LED bug (file_read → led_set chain fires with empty args), reasoning-trace leak into wrap-up text

Preserve the historical sections lower in the file — don't delete the bisect-era content, just replace the "Current state pointer" at top and prepend a new "Recent phases (4.0.x–4.1.x)" section.

---

## Step 2 — Workspace git audit

Scott has initialized the git repo + remote at the workspace root (`C:\Users\homet\Documents\WireClaw\` in Windows, `/mnt/c/Users/homet/Documents/WireClaw/` in WSL). Confirm:

```bash
cd /mnt/c/Users/homet/Documents/WireClaw && git status && git remote -v && git log --oneline | head -10
```

Report: is `.git/` present? What's the remote URL? Are there any commits yet, or fresh repo? What files are staged / untracked / modified?

---

## Step 3 — Stage + commit workspace milestones

Stage these (include all if present; skip silently if any are missing):

- `CLAUDE.md`
- `PROJECT_STATUS.md` (the rewritten version from Step 1)
- `SOUL.md` (the constitution — canonical 26 articles)
- `sync/worklog.md`, `sync/to_code.md`, `sync/from_code.md`
- `sync/queued_p05_upstream.md`, `sync/drafts/*.md` (the GitHub PR drafts — these belong in the repo)
- `bench/fork/PATCHES.md`, `bench/fork/HANDOFF.md`
- `bench/fork/patches/*.md` (all drafted upstream/fork patches)
- `bench/fork/bake/PLAN.md`, `bench/fork/bake/BUILD-LOG.md`
- `bench/fork/lora/*.md` (PHASE3.md, RIG.md, CORPUS_CAPTURE.md, SDCARD_PROVISIONING.md, PHASE3.0-wrap-up-classifier.md, HANDOFF.md if present)
- `bench/fork/lora/training-data/constitution/*.md` (SOUL-LOCAL.md, SOUL-CHIP.md, plus the canonical SOUL.md mirror)
- `bench/fork/lora/training/BREV_RUNBOOK.md`, `bench/fork/lora/training/BREV_GOTCHAS.md`, `bench/fork/lora/training/smoke_test.py`
- `bench/fork/lora/corpus-labels/*.md`
- `bench/fork/lora/personas/*.py` (the safe-pin-remapped personas)
- `bench/fork/lora/corpus/quarantine/` (the scrambled corpus + README) — yes, commit this; it's a documented known issue
- `bench/fork/lora/corpus/v1.1-overnight-2026-05-18.REPAIRED.jsonl` IF salvage completed and Scott wants the corpus in repo (decision below)
- `sdcard-images/*.sh` (all the phase scripts)
- `OPEN_QUESTIONS.md`, `baking-constitutional-models-8gb-vram.md`

**Decision needed before staging:** does the repaired corpus belong in the repo, or in a separate corpus-storage location (e.g., git-LFS, or HuggingFace datasets)? JSONL corpora can be tens of MB and don't diff well. Surface the corpus size and ask Scott. Default recommendation: store recovered corpus in HuggingFace datasets (Step 7 below), not in main repo — only commit a manifest/sample.

**Explicitly EXCLUDE from this commit:**

- Any Secrets.txt, .env, *_token*, or files containing API tokens / SSH keys / Telegram bot tokens. **Grep the stage list for sensitive content before committing.**
- The raw `corpus/raw/` directory (huge, regenerable from azza)
- `.pio/`, `__pycache__/`, `node_modules/`, any build artifacts
- The Brev training output (`output/` from the training runs — those go to HF, not main repo)

Add a `.gitignore` if not present, covering the exclusions above.

**Commit message:**

```
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
```

Sign as Scott Whitney. Report commit hash. **Do NOT push yet** — push is Step 4.

---

## Step 4 — Push to origin (gated on Scott confirmation)

After Step 3 commit lands, report the commit hash + remote URL to Scott in chat output and pause. Push only after Scott explicitly confirms (workspace push is L2 within directive scope but worth surfacing because this is the *first* push to the new public-ish repo — Scott may want to review the staged files list one more time before it goes public).

When confirmed:

```bash
cd /mnt/c/Users/homet/Documents/WireClaw && git push -u origin main
```

Or whatever branch Scott set up. Report success.

---

## Step 5 — WireClaw-fork audit

Confirm the firmware fork's remote state matches our records:

```bash
cd /mnt/c/Users/homet/Documents/WireClaw-fork
git log --oneline wdl-v1 | head -5
git status
git remote -v
git fetch --all
git log --oneline origin/wdl-v1 | head -5  # confirm bf80fa9 is on remote
```

Verify `bf80fa9` is the tip of `origin/wdl-v1`. Report any uncommitted local changes (there shouldn't be — Code committed clean yesterday — but verify).

Bonus: check the upstream PR thread for P05 (issue #12 at M64GitHub/WireClaw) — has Mario responded since the last check? `gh issue view 12 --repo M64GitHub/WireClaw` should show comment history.

Report findings.

---

## Step 6 — HuggingFace model release prep

This step is **prep only** — no upload until Scott approves.

a. **Locate the v1.1 LoRA adapter binaries.** They were downloaded from Brev after training; should live somewhere accessible. Check `bench/fork/lora/training/output/`, `~/wireclaw-v1-brev/`, anywhere else likely. Find:
   - `adapter_config.json`
   - `adapter_model.safetensors` (or `adapter_model.bin`)
   - Training metrics / loss curves if preserved
   - Tokenizer files if separate
   - GGUF conversion output (the file actually loaded by Ollama)

b. **Draft the HuggingFace model card** (`bench/fork/lora/hf-publish/README.md`). Standard sections:
   - Model overview: "WireClaw Agent v1.1 — LoRA adapter for Llama 3.1 8B Instruct, fine-tuned for embedded-AI tool use on ESP32-C6 microcontrollers under the Project Opengates constitution"
   - Base model: `meta-llama/Llama-3.1-8B-Instruct`
   - Training: QLoRA, r=16, alpha=32, all-linear targets, 3 epochs, batch 8, lr 2e-4, dataset breakdown (3.1.3 corpus + synthetic constitutional examples + memory-chain examples)
   - License: **Llama 3.1 Community License** (governs derivatives). Add the standard "Built with Llama" attribution.
   - Intended use: embedded AI agents under a constitutional framework, tool-use on ESP32-class hardware
   - Out-of-scope use: weaponization (Article 3), deception (Article 2), anything Part II of SOUL.md prohibits
   - Constitution: link to / embed SOUL.md
   - Performance: smoke test 10/10 pass, real-world deployment notes (42/42 emergency_stop survival post-firmware-fix, 11-hour overnight stability)
   - Known limitations: indirect-reference LED bug, reasoning-trace leak, residual pseudo-prose at ~5%
   - Training data: summarize what's in the corpus (not the corpus itself if any PII concern)
   - Citation / attribution: Project Opengates, Whitney Design Labs

c. **Identify what Scott needs to set up before upload can fire** (he doesn't have to do these now — just inventory them):
   - HuggingFace account (probably `WhitneyDesignLabs` org or `scottwhitney7` user)
   - HF API token with write scope (https://huggingface.co/settings/tokens)
   - Repo name (suggest `wireclaw-agent-v1.1-lora` or `whitneydesignlabs/wireclaw-agent`)
   - License acceptance for Llama 3.1 base model on HF (one-click on the meta-llama org page)

Report Step 6 findings to `from_code.md`: which adapter files exist, the model card draft, and what Scott still needs to set up.

---

## Step 7 — HuggingFace upload (gated on Scott confirmation + HF setup)

When Scott confirms HF account ready + token in hand:

```bash
pip install --user huggingface_hub
huggingface-cli login   # interactive, Scott runs this with his token
huggingface-cli repo create wireclaw-agent-v1.1-lora --type model
# Then upload via Python script or:
huggingface-cli upload <repo-id> <local-dir> --commit-message "Initial release: wireclaw-agent v1.1 LoRA adapter"
```

Don't initiate this autonomously. Scott authorizes, Scott provides the token, Code drives the upload commands.

After upload: confirm the model loads via the standard HF flow:

```python
from peft import PeftModel
from transformers import AutoModelForCausalLM
base = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
model = PeftModel.from_pretrained(base, "<scott's-hf-id>/wireclaw-agent-v1.1-lora")
```

A standalone Python script that does this load + a one-shot inference smoke test is the validation. Run on a machine with enough VRAM (k-scale-trainer if available, else skip and trust the upload).

---

## Step 8 — GitHub release tag (gated on Scott confirmation)

After workspace push (Step 4) lands and HF upload (Step 7) completes, tag a release on the workspace repo to mark the milestone:

```bash
git tag -a v1.1-milestone -m "Phase 4.1.x close: first stable v1.1 capture + firmware fleet recovery"
git push origin v1.1-milestone
```

Also consider tagging WireClaw-fork at `bf80fa9` as `firmware-v0.4.1` or similar so the firmware version is discoverable from the GitHub releases page.

---

## Step 9 — Big-picture review (Cowork + Scott, NOT a Code task)

After Steps 1–8 land, write a brief consolidated handback to `from_code.md` summarizing what shipped where (commit hashes, HF URL, tag names). Then **stop**. The next phase is Cowork + Scott doing a goal/metrics review together before authorizing the v1.3 training round or any other forward work. Code waits for the next directive.

---

## Reporting cadence

Surface each step's completion as it happens (Step 1 PROJECT_STATUS rewrite → Step 2 git audit → ... → Step 8 tag). Steps 4, 7, 8 each have explicit Scott-gate language. Steps 3 and 6 surface decisions Scott needs to make (corpus in repo or HF datasets; HF org name; etc.).

## Out of scope

- Haiku labeling (post-housekeeping decision)
- v1.3 training (post-big-picture-review decision)
- New capture rounds
- c6-01 reflash (Phase 4.0.5)
- Firmware 4.0.4 hardening (rule revalidation, snprintf audit, crash watchdog)
- Mario PR follow-throughs (P01-P06 issues / PRs) — separate session work, not this directive's scope

## Constraints

- Never commit secrets (tokens, keys). Grep the stage list.
- Don't auto-push to remote without Scott explicit confirmation per step.
- Llama 3.1 license attribution is required on the HF model card — non-negotiable per the Community License terms.
- Sign all commits as Scott Whitney. No Code-as-author byline anywhere.
