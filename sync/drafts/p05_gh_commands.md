# P05 first-contact upstream — gh CLI commands (Scott runs these)

**Pre-flight checklist before running anything in this file:**

- [ ] Read `sync/drafts/p05_issue.md` and `sync/drafts/p05_pr.md` end-to-end
- [ ] If wording feels off, ask Cowork to revise (Code can re-draft)
- [ ] Confirm WSL `gh auth status` shows logged-in to github.com
- [ ] Confirm you're at `C:\Users\homet\Documents\WireClaw-fork` in WSL/PowerShell
- [ ] Confirm current branch: `git branch --show-current` should print `p05-serial-send-clarification`
- [ ] Sanity-check the diff: `git diff upstream/main..HEAD --stat` should show `src/tools.cpp | 2 +-` (1 insertion, 1 deletion, no other files)

Only proceed once all six boxes are checked.

---

## Step 1: Push the branch to your fork

The branch lives only locally right now. Push it to `WhitneyDesignLabs/WireClaw` so the PR can be opened from it later.

```bash
cd /mnt/c/Users/homet/Documents/WireClaw-fork  # or PowerShell equivalent
git push origin p05-serial-send-clarification
```

This pushes a brand-new branch to your fork. It does NOT trigger any notification to Mario.

---

## Step 2: File the issue

This is the first thing Mario will see. Per `bench/fork/PATCHES.md` etiquette, the issue is the lightweight first contact — Mario decides whether to engage before any PR appears.

```bash
gh issue create --repo M64GitHub/WireClaw \
  --title "serial_send tool description: clarify newline behavior" \
  --body-file sync/drafts/p05_issue.md
```

`gh` will return the issue URL — note the issue number from the URL (e.g., `#1`, `#7`).

---

## Step 3: WAIT for Mario's response

This is the critical wait. Per HANDOFF.md and PATCHES.md etiquette:

- Could be hours, days, or weeks. Mario is single-maintainer on a small project.
- Don't open a parallel PR before he engages — that's the etiquette violation we're explicitly avoiding.
- Acceptable response patterns from Mario:
  - "Yes, send a PR" → proceed to step 4
  - "I think the current wording is fine because X" → close conversation politely, don't argue
  - "Could you also do Y while you're at it?" → judgement call; small Y can be added to the PR, large Y deserves its own issue
  - Silence > 2 weeks → polite "any thoughts on this?" comment is fine, then more silence is fine
- Code/Cowork should be re-engaged when Mario responds, NOT before.

---

## Step 4: Create the PR (only after Mario engages positively)

Once Mario has indicated he's open to the patch, edit `sync/drafts/p05_pr.md` and replace `<ISSUE_NUMBER>` with the actual number from step 2. Then:

```bash
gh pr create --repo M64GitHub/WireClaw \
  --base main \
  --head WhitneyDesignLabs:p05-serial-send-clarification \
  --title "Clarify serial_send newline behavior in tool description" \
  --body-file sync/drafts/p05_pr.md
```

`gh` returns the PR URL. Note it for the worklog.

---

## Step 5: Update PATCHES.md status row

After the PR is open, update the P05 row in `bench/fork/PATCHES.md`:

```
| P05 | drafted → filed (issue #N) → PR open (#M) → ... | ... |
```

Per HANDOFF.md, this is the canonical state — don't track patch status in chat history.

---

## Step 6: Respond to PR review

If Mario requests changes, push follow-up commits to `p05-serial-send-clarification` (they automatically appear in the PR). Don't squash unless asked. If Mario closes without merging, that's also OK — the patch lives on in `WhitneyDesignLabs/WireClaw`.

---

## Rollback / clean-up if you change your mind before pushing

```bash
git checkout main
git branch -D p05-serial-send-clarification
```

The local branch goes away and nothing was sent to GitHub.

---

## What Code DID NOT do this round

- Did NOT push to origin
- Did NOT file the issue
- Did NOT open the PR
- Did NOT touch `bench/fork/PATCHES.md`

All external actions are gated on Scott's explicit go-ahead per `to_code.md`.
