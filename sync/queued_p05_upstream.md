# QUEUED Directive — P05 Upstream Issue + PR (do not execute until promoted)

**Status:** Draft. Not active. Sits queued for after the P02-redesign handback is reviewed. When ready to activate, this file's contents get copied to `sync/to_code.md` (overwriting the P02-redesign directive that will have already been completed).

**Why this is queued, not active:** Cowork agreed with Scott to prep the next directive in parallel without committing Code to anything yet — P02-redesign findings might shift priorities (e.g., if P02-redesign reveals that P05 should ship together with a system-prompt rewrite, or if hardware behavior surprises us).

---

# Instructions for Claude Code

## Context: P05 upstream PR prep (no posting until Scott approves)

The bisect closed clean. P05, P06, P01 are exonerated as patch-attributable regression sources. P05 was always the planned "friendliest first contact" upstream PR — smallest scope, demonstrably-fixes-a-bench-failure, low risk for Mario to review.

This directive does the prep work for filing a single Issue + a single PR at `M64GitHub/WireClaw` for P05 only. **NOTHING gets posted to GitHub in this round.** All work product is drafts that Scott reviews in chat before any external action. Mario is a solo maintainer with 15 stars; first contact has to be polite, deferential, and demonstrate Scott did his homework.

Do NOT open P01, P04, P06 PRs in this round. One issue + one PR at a time per the original shipping plan in `bench/fork/HANDOFF.md`.

---

## Your immediate task

### Step 1: read the source material

```
bench/fork/HANDOFF.md                          # shipping mechanics, gh CLI workflow
bench/fork/PATCHES.md                          # ordering, bucketing, etiquette
bench/fork/patches/P05-serial-send-description.md  # the actual P05 patch
```

Then check the WireClaw-fork tree:

```powershell
cd C:\Users\homet\Documents\WireClaw-fork
git log --all --oneline | head -30
git branch -a
```

There should be a `P05-serial-send-description` local branch with the actual P05 commit. Confirm the commit SHA (Scott referenced `bbfd006`-style SHAs in prior handbacks; verify by inspection). Read the diff to understand exactly what's changing — should be a one-line description tweak in `data/tools.json` or equivalent for the `serial_send` tool.

### Step 2: prepare a clean upstream-base branch

For Mario's review, we want a PR branch that's NOT off any of the local bisect branches — those have unrelated commits Mario doesn't need to see. The branch should be off `upstream/main`:

```powershell
cd C:\Users\homet\Documents\WireClaw-fork
git fetch upstream
git checkout -b p05-serial-send-clarification upstream/main
git cherry-pick <P05-SHA>
```

Verify the diff is minimal — ideally one file, one or two lines of description text changed. If it's not minimal, STOP and report (the original P05 commit may have included unrelated changes that need stripping).

DO NOT push to origin yet. The branch sits locally for Scott's review.

### Step 3: draft the Issue body

Write to `sync/drafts/p05_issue.md` (create the `drafts/` directory if needed). The Issue should:

- **Title:** Short, descriptive. Suggested: `serial_send tool description: clarify newline behavior` (you may improve).
- **Body structure:**
  - One-paragraph statement of the bug — what the description currently says, why it's ambiguous, what observable failure it produces.
  - Empirical evidence — refer to the bench finding (T19 "Send GET_TEMP over serial" fails on 2/5 models because of the ambiguous "newline appended" wording). Cite that this was reproduced on at least two specific models (refer to bench results in `bench/results/run-20260511T170249Z.md`).
  - Proposed fix — describe in plain English what the new wording would say. Do NOT show the diff inline; that goes in the PR.
  - Tone: technical, friendly, deferential. Acknowledge Mario's ownership ("I've drafted a fix and would be happy to send a PR if you think this is worth changing").
  - Length: aim for ~150-300 words. Mario should be able to read it in 30 seconds and decide whether to engage.

The Issue is the LIGHTWEIGHT first contact. The PR comes after Mario expresses interest. Do not pre-empt by mentioning the PR is already prepared.

### Step 4: draft the PR description

Write to `sync/drafts/p05_pr.md`. The PR body should:

- **Title:** Match the Issue or be tightly aligned (e.g., `Clarify serial_send newline behavior in tool description`).
- **Body structure:**
  - One-line link: `Fixes #<issue-number>` (placeholder; Scott fills the actual number after the Issue is filed).
  - Short summary of the fix — one paragraph.
  - The diff context — explain what the wording change accomplishes.
  - Empirical impact — note that this resolves the T19 failure on the bench. ONE benchmark table line is acceptable; do not paste the full bench results.
  - Tone: collaborative, not assertive. "This is offered as a small clarification; happy to revise based on your preferences."
  - Length: shorter than the Issue. ~100-150 words.

### Step 5: stage the git mechanics (but don't execute external commands)

Draft the exact `gh` CLI commands Scott would run, save to `sync/drafts/p05_gh_commands.md`:

```bash
# After Scott approves drafts in chat:
# 1. Push the branch to fork
git push origin p05-serial-send-clarification

# 2. File the issue (Mario sees this first)
gh issue create --repo M64GitHub/WireClaw --title "..." --body-file sync/drafts/p05_issue.md

# 3. WAIT for Mario's response on the issue (could be days/weeks). Only proceed when Mario indicates interest.

# 4. Open the PR linked to the issue:
gh pr create --repo M64GitHub/WireClaw --base main --head WhitneyDesignLabs:p05-serial-send-clarification --title "..." --body-file sync/drafts/p05_pr.md
```

Include explicit notes about timing: file the Issue, then WAIT for Mario's reaction before opening the PR. Don't surprise him with a parallel PR he didn't ask for. (Per `bench/fork/PATCHES.md` etiquette section.)

### Step 6: stop and report

DO NOT push, DO NOT run `gh issue create`, DO NOT run `gh pr create`. All Code does this round is:

- Verify the P05 patch is minimal and clean
- Stage the branch locally
- Draft three files in `sync/drafts/`
- Write the handback

Scott reads the drafts in chat, requests revisions if needed, and runs the gh commands himself. The actual posting is gated entirely on Scott's explicit go-ahead.

### Handback expectations

Overwrite `sync/from_code.md` with:

- Confirmation of the P05 branch state (SHA, base branch, file changes).
- Paths to the three draft files.
- Inline summary (not full text) of what each draft contains.
- Any concerns or open questions about the patch quality or PR tone.
- Recommended next step (likely: Scott reviews drafts, requests changes if any, then runs the gh commands manually).

Short chat: "P05 upstream PR prep complete, drafts in `sync/drafts/`, awaiting Scott's review and approval to post."

Append a worklog entry.

---

## Workflow rules (unchanged)

1. Never generate user-side turns.
2. Chat output is short pointers; detailed handbacks go in `sync/from_code.md`.
3. Append worklog entry on completion.
4. **NOTHING gets pushed or posted to external services in this round.** All work product is local drafts.
5. Re-read `sync/to_code.md` at the top of every Code turn.

## If anything goes wrong

If the P05 branch doesn't exist or the cherry-pick produces unexpected diff: STOP and report. The original P05 patch should be tiny; if it's not, something's wrong with the source material.

If the bench result for T19 (referenced in the Issue draft) doesn't match what `bench/results/` shows, fix the draft to match the actual evidence — don't invent numbers.

If the upstream main has moved significantly since the local fork was set up and there are merge conflicts on the cherry-pick, STOP and report — Scott may want to rebase fork's main first.

If anything else is unclear, STOP and ask.
