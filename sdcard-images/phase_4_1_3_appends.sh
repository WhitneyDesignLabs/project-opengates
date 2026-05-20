#!/bin/bash
# Phase 4.1.3 Step 6: worklog entry + OPEN_QUESTIONS.md entry for the
# canonical SOUL URL discoverability push.
set -u
WL=/mnt/c/Users/homet/Documents/WireClaw/sync/worklog.md
OQ=/mnt/c/Users/homet/Documents/WireClaw/OPEN_QUESTIONS.md

cat >> "$WL" <<'WORKLOG'


## 2026-05-19 — Phase 4.1.3 canonical SOUL URL discoverability + repo rename

**The day in one line:** Made `https://clawhub.ai/souls/opengates-constitution` the discoverable canonical reference everywhere SOUL is referenced — HuggingFace model card, workspace `README.md` (new), `SOUL.md` top anchor, `CLAUDE.md` Constitution section, fork `README-WhitneyDesignLabs.md`, `PROJECT_STATUS.md` top pointer. Goal: downstream humans and agents don't hunt for the binding constitutional text — one URL, every artifact links to it.

**Files updated:**
- `bench/fork/lora/hf-publish/README.md` — Constitution section restructured with canonical URL + version 0.2.0; out-of-scope use replaced with explicit article citations linking to the canonical; License section cross-references the canonical alongside Llama 3.1.
- `README.md` at workspace root — NEW. Landing page with canonical URL, project links (firmware fork + HF model + SOUL.md), current state pointer, file index, "Built with Llama" attribution.
- `SOUL.md` — top-of-file canonical anchor block prepended (article content untouched per directive constraint).
- `CLAUDE.md` — Constitution section replaced with canonical-URL-anchored version.
- `PROJECT_STATUS.md` — canonical-URL line added at the top of Current state pointer.
- `bench/fork/lora/training-data/constitution/SOUL-LOCAL.md` and `SOUL-CHIP.md` — verified to already reference the canonical URL in their headers (with `www.` prefix, functionally equivalent to no-www). Left untouched as as-trained artifacts — model was trained on these exact bytes; updating now creates a drift between training data and shipped repo that's harmless for discoverability and best resolved at the next training cycle (v1.3) when SOUL files are re-baked anyway.

**ClawHub-vs-onlycrabs.ai decision:** ClawHub (`clawhub.ai/souls/opengates-constitution`) is the user-facing canonical for now per Scott. The chip-baked SOUL-CHIP.md and the training-distilled SOUL-LOCAL.md both reference this URL; aligning every other surface preserves that consistency. The `onlycrabs.ai` meta-canonical question is acknowledged but out of scope.

**Repo rename:** `project-opengates-` → `project-opengates` (trailing-dash typo cleanup). Scott did the rename in browser; Code updated the local origin remote. GitHub auto-redirects the old URL for ~90 days.

**Fork branch:** `docs-canonical-soul-url` pushed to fork origin (commit `54d6cea`). No upstream PR (WhitneyDesignLabs-specific content). Scott can fast-forward into `wdl-v1` if he wants the canonical anchor visible on the fork's default-branch README view.

**Workspace milestone tag:** `v1.1-milestone-canonical-url` to be set at the consolidated Phase 4.1.3 commit, pushed to `origin`.

### Tag

"2026-05-19 — Phase 4.1.3 close: canonical SOUL URL (clawhub.ai/souls/opengates-constitution) now linked from every public artifact; workspace repo renamed off trailing-dash typo; fork has a docs branch with the same anchor."
WORKLOG

echo "appended to worklog.md"
echo

# OPEN_QUESTIONS.md — append the future canonical-hierarchy entry per directive.
cat >> "$OQ" <<'OQENTRY'


## Canonical SOUL URL hierarchy — long-term plan (Phase 4.1.4 or later)

Phase 4.1.3 made `https://clawhub.ai/souls/opengates-constitution` the discoverable canonical everywhere SOUL is referenced. This is a usable but interim arrangement. Scott has decided the long-term hierarchy:

1. **Primary canonical:** `projectopengates.org/constitution` (path under a domain Scott controls). The domain is live; the constitution page does NOT yet exist — needs to be published (Squarespace or equivalent, just SOUL.md content + version + last-modified header).
2. **Authoritative mirror:** GitHub raw URL at a tagged commit (e.g. `https://raw.githubusercontent.com/WhitneyDesignLabs/project-opengates/v0.2.0/SOUL.md`). Content-addressed by git SHA — tamper-evident for agents needing cryptographic verification.
3. **Public-record references:** ClawHub (`clawhub.ai/souls/opengates-constitution`), HuggingFace model card, etc. Broader distribution, lesser control. Demoted from canonical to mirror once #1 ships.

**Open task — publish `projectopengates.org/constitution`:** when the page is live, Phase 4.1.4 swaps the primary reference across every artifact (HF model card, workspace README, SOUL.md anchor, CLAUDE.md Constitution section, fork README, PROJECT_STATUS pointer). The chip-bake SOUL files (`SOUL-LOCAL.md` / `SOUL-CHIP.md`) get the URL change naturally during the next training cycle (v1.3); no separate firmware flash needed for the URL change.

**Why this is queued (not Phase 4.1.3):** publishing on projectopengates.org is a human-action task (Squarespace edit + DNS verify); ClawHub is the right user-facing canonical until the long-term primary exists.
OQENTRY

echo "appended to OPEN_QUESTIONS.md"
echo "-- tails --"
echo "worklog:"; tail -n 5 "$WL"
echo
echo "open-questions:"; tail -n 5 "$OQ"
