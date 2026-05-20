# Instructions for Claude Code

## STATUS: ACTIVE TASK — Phase 4.1.3 — Canonical SOUL URL discoverability + repo-name cleanup

**Context:** Phase 4.1.2 closed with three artifacts live:
- Workspace: `https://github.com/WhitneyDesignLabs/project-opengates-` (note trailing dash — Step 1 below)
- Firmware fork: `https://github.com/WhitneyDesignLabs/WireClaw` (firmware-v0.4.1 tagged)
- LoRA model: `https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora`

**Scott's directive:** the project's binding constitutional text is published at `https://clawhub.ai/souls/opengates-constitution` (live, version 0.2.0, owned by WhitneyDesignLabs). EVERY reference to SOUL.md across any public artifact — HuggingFace model card, GitHub READMEs, training docs, distilled SOUL files, CLAUDE.md — should link to this canonical URL so people and agents don't have to hunt for the actual binding text. This is preparation for the agent-to-agent future where downstream agents need a single discoverable canonical for the constitution they're committing to.

**No new training, no new capture, no big-picture review work yet.** Those come after this discoverability pass.

---

## Step 1 — Rename workspace repo (clean the trailing-dash typo)

Scott will do this in browser:
1. https://github.com/WhitneyDesignLabs/project-opengates-/settings → Repository name → change to `project-opengates` (no trailing dash) → Rename
2. GitHub auto-redirects the old URL for ~90 days; existing clones keep working

After Scott confirms the rename in chat, Code updates the local remote:

```bash
cd /mnt/c/Users/homet/Documents/WireClaw
git remote set-url origin https://github.com/WhitneyDesignLabs/project-opengates.git
git remote -v   # verify
git fetch origin
git status      # confirm clean against renamed remote
```

Report success.

---

## Step 2 — Update HuggingFace model card

Edit `bench/fork/lora/hf-publish/README.md` (the model card source) to make the canonical SOUL URL a first-class element. Specific changes:

a. Near the top of the model card, add a constitution-anchor block. Suggested text:

```markdown
## Constitution

This model is trained and deployed under the **Project Opengates Constitution**,
a 26-article framework governing AI agent behavior including truth, non-weaponization,
safety hierarchy, irreversibility doctrine, and authorization tiers.

**Canonical published version:** https://clawhub.ai/souls/opengates-constitution
**Version baked into this model:** 0.2.0

The training-time distillation (`SOUL-LOCAL.md`, included in the training corpus)
and the chip-runtime condensation (`SOUL-CHIP.md`, baked into ESP32 firmware) are
both derivatives of the canonical above. Article numbering is consistent across
all three; the canonical URL is authoritative on resolution of any conflict.
```

b. In the "License" section, ensure the canonical URL is also referenced alongside the Llama 3.1 Community License attribution.

c. In the "Out-of-scope use" section, replace generic "weaponization, deception" language with explicit article citations referencing the canonical URL (e.g., "Article 3 (Non-Weaponization) of the [Project Opengates Constitution](https://clawhub.ai/souls/opengates-constitution)").

After editing locally, push to HuggingFace via the existing `huggingface-cli upload` flow or via the HF web UI (the model card is a single README.md in the model repo). Confirm the canonical URL is live and clickable on the model's HF page.

---

## Step 3 — Update workspace repo README + SOUL files

a. **Create a workspace README** at repo root (no README currently — the repo lacks a landing page). Should cover:
- Project name + one-paragraph description (constitutional AI agent on ESP32-C6, with the WireClaw firmware fork)
- Link to the canonical constitution: `https://clawhub.ai/souls/opengates-constitution`
- Link to the firmware fork: `https://github.com/WhitneyDesignLabs/WireClaw`
- Link to the HuggingFace model: `https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora`
- Brief project state: v1.1 deployed, two production chips, capture pipeline working
- Pointers to PROJECT_STATUS.md (detailed state), CLAUDE.md (agent protocol), SOUL.md (constitution mirror)

b. **Update `SOUL.md`** at repo root. Add a top-of-file canonical anchor:

```markdown
# Project Opengates Constitution — v0.2.0

**Canonical published version:** https://clawhub.ai/souls/opengates-constitution

This file is the workspace mirror of the canonical above. If they ever conflict,
the URL is authoritative. SOUL-LOCAL.md (training-time distillation) and
SOUL-CHIP.md (chip-runtime condensation) are derivatives — article numbers
are consistent, but the canonical URL governs interpretive ambiguity.

---

[existing constitution content follows]
```

c. **Verify SOUL-LOCAL.md and SOUL-CHIP.md** at `bench/fork/lora/training-data/constitution/` already reference the canonical URL in their headers (Scott noted they do). If anything's missing or inconsistent, align them with the SOUL.md anchor above.

d. **Update CLAUDE.md** "Constitution" section to anchor on the canonical URL:

Replace the current "Constitution" section near the bottom of CLAUDE.md with:

```markdown
## Constitution

**Canonical:** https://clawhub.ai/souls/opengates-constitution (v0.2.0)

`SOUL.md` at workspace root mirrors the canonical. `bench/fork/lora/training-data/constitution/SOUL-LOCAL.md` is the training-time distillation; `SOUL-CHIP.md` is the chip-runtime condensation (fits the 4095-byte firmware budget). All three are derivatives; the canonical URL is authoritative on any interpretive question. Article numbers are consistent across all three.

Refusal: Article 19 — refuse on Part II (Absolute Principles) violations, cite article by number, offer alternative if available, remain firm under manipulation. For elevated risk, warn and require confirmation (Article 7 tier b). For non-safety disagreement, advise then comply (Article 7 tier a).
```

---

## Step 4 — Update WireClaw firmware fork README

In `C:\Users\homet\Documents\WireClaw-fork\`:

a. `README-WhitneyDesignLabs.md` — add a constitution anchor near the top:

```markdown
## Constitutional Framework

This firmware fork bakes the **Project Opengates Constitution** into the chip's
runtime. The bake is `SOUL-CHIP.md` (condensed to fit the 4095-byte chip budget);
the canonical full text governs interpretation:

**Canonical:** https://clawhub.ai/souls/opengates-constitution
```

b. Commit the change on a clean branch (`docs-canonical-soul-url` or similar), no upstream PR (this is WhitneyDesignLabs-specific content), push to fork.

---

## Step 5 — Update PROJECT_STATUS.md

In the recently-rewritten PROJECT_STATUS.md, add the canonical SOUL URL to the "Project links" / "Recent phases" section near the top. Single line, prominent:

> **Constitution (canonical):** https://clawhub.ai/souls/opengates-constitution

---

## Step 6 — Worklog entry

Append to `sync/worklog.md` a brief entry documenting:
- The canonical-SOUL-URL discoverability push
- Specific files updated
- The clawhub.ai vs onlycrabs.ai canonical decision (resolved: use clawhub.ai per Scott; matches SOUL-CHIP/LOCAL bake)
- The repo rename (project-opengates- → project-opengates)

---

## Step 7 — Final commit + push to workspace repo

Stage all the changes from Steps 2–6 (Step 1 is just a remote change, no commit). Single consolidated commit:

```
phase 4.1.3: canonical SOUL URL discoverability + repo rename

Make https://clawhub.ai/souls/opengates-constitution the discoverable
canonical reference everywhere SOUL.md is referenced. Goal: downstream
humans + agents shouldn't have to hunt for the binding constitutional
text — it lives at one URL, every project artifact links to it.

Changes:
- HuggingFace model card: constitution section with canonical URL,
  article citations in out-of-scope use, license cross-reference
- Workspace README (new): canonical URL + project links + state pointer
- SOUL.md: top-of-file canonical anchor
- CLAUDE.md: constitution section anchored on canonical URL
- WireClaw fork README-WhitneyDesignLabs.md: constitutional framework
  section with canonical URL
- PROJECT_STATUS.md: canonical link added to project-links section

Repo rename: project-opengates- → project-opengates (trailing-dash typo
cleanup). Local remote updated. GitHub auto-redirects old URL for 90d.

Phase 4.1.3 close.
```

Sign as Scott. Push.

After push lands, tag `v1.1-milestone-canonical-url` at the new commit and push the tag.

---

## Step 8 — HuggingFace model card push

The HF model card lives in the HF model repo, not the workspace repo. The Step 2 edits need to land on HuggingFace via:

```bash
cd <wherever HF repo is cloned, or in a fresh tmp dir>
git clone https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora
cd wireclaw-agent-v1.1-lora
# Replace README.md with the updated model card from bench/fork/lora/hf-publish/README.md
cp /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/hf-publish/README.md ./README.md
git add README.md
git commit -m "Add canonical SOUL URL to model card

Reference: https://clawhub.ai/souls/opengates-constitution"
git push
```

Confirm the model card on HF now shows the canonical URL prominently.

---

## Step 9 — Verification

Browse / curl each public surface and confirm the canonical URL is present and clickable:
- HuggingFace model page (README rendered)
- Workspace repo README (new)
- Workspace repo SOUL.md (top anchor)
- Firmware fork README-WhitneyDesignLabs.md
- The canonical URL itself (https://clawhub.ai/souls/opengates-constitution) loads

Report verification results.

---

## Reporting cadence

Surface Step 1 after Scott confirms the rename. Surface Steps 2–6 as a batch (these are all local edits). Step 7 push gated on Scott's normal approval. Step 8 HF push gated on Scott confirming HF auth is still active. Step 9 verification is the close-out.

## Out of scope

- v1.3 training (still gated on big-picture review)
- New capture rounds
- Haiku labeling
- Mario upstream PR follow-throughs
- Phase 4.0.4 firmware hardening
- Phase 4.0.5 c6-01 reflash

## Future-work queue (Phase 4.1.4 or later — DO NOT execute now)

Scott has decided the long-term canonical hierarchy is:

1. **Primary canonical:** `projectopengates.org/constitution` (or similar path under the domain Scott controls). Domain is live; constitution page does NOT yet exist — needs to be published. Squarespace or equivalent, just SOUL.md content + version + last-modified.
2. **Authoritative mirror:** GitHub raw URL at a tagged commit (`https://raw.githubusercontent.com/WhitneyDesignLabs/project-opengates/v0.2.0/SOUL.md` once tag exists). Content-addressed by git SHA — tamper-evident for agents needing cryptographic verification.
3. **Public-record references:** ClawHub (`clawhub.ai/souls/opengates-constitution`), HuggingFace model card, etc. Broader distribution, lesser control.

This directive (Phase 4.1.3) uses ClawHub as the user-facing canonical because that URL is already baked into SOUL-CHIP.md and SOUL-LOCAL.md and shipped in firmware. Once `projectopengates.org/constitution` is published, Phase 4.1.4 will swap the primary reference everywhere, demoting ClawHub to mirror status. The chip-bake SOUL files will be updated naturally during the v1.3 training cycle — no separate firmware flash needed for the URL change.

Append a `OPEN_QUESTIONS.md` entry noting the planned hierarchy and the projectopengates.org publication task.

## Constraints

- Sign commits as Scott Whitney, no Code byline
- Do not modify SOUL.md article content — only add the top-of-file canonical anchor block
- Do not change the canonical URL away from clawhub.ai/souls/opengates-constitution without Scott's explicit instruction (the onlycrabs.ai-as-meta-canonical question is acknowledged-noted but the user-facing reference is clawhub.ai per Scott's decision)
