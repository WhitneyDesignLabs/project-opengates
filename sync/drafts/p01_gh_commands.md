# P01 upstream — gh CLI commands (Scott runs these)

> ## ⏸ PAUSED: do not run any command in this file until P05 ([#12](https://github.com/M64GitHub/WireClaw/issues/12)) is resolved
>
> Per `bench/fork/PATCHES.md` etiquette: one issue + one PR at a time, breathing room between each, watch Mario's response style and pace. Filing P01 in parallel with an open P05 issue would violate that — Mario would see two unsolicited issues from the same person at once. Wait until P05 is merged, declined, or otherwise closed before starting on this file.
>
> Acceptable resolutions of P05 that unblock P01:
> - PR merged
> - PR opened and under review
> - Issue declined ("not interested" or equivalent)
> - Issue closed without engagement after a polite ping at ~2 weeks of silence
>
> If P05 is mid-review with active back-and-forth, hold P01 until that conversation reaches a stable state.

---

**Pre-flight checklist (do this once P05 is resolved and you're ready):**

- [ ] P05 (#12) is resolved per the criteria above
- [ ] Re-read `sync/drafts/p01_issue.md` and `sync/drafts/p01_pr.md` end-to-end
- [ ] If wording feels off, ask Cowork to revise (Code can re-draft)
- [ ] Confirm WSL `gh auth status` shows logged-in to github.com
- [ ] Confirm you're at `/mnt/c/Users/homet/Documents/WireClaw-fork` in WSL
- [ ] Confirm current branch: `git branch --show-current` should print `p01-prose-tool-call-leak-detector`
- [ ] Sanity-check the diff: `git diff upstream/main..HEAD --stat` should show approximately:
  ```
  include/llm_client.h | 11 +++++
  src/llm_client.cpp   | 107 ++++++++++
  src/main.cpp         | 20 ++++++
  3 files changed, 138 insertions(+)
  ```

Only proceed once all seven boxes are checked.

---

## Step 1: Push the branch to your fork

```bash
cd /mnt/c/Users/homet/Documents/WireClaw-fork
git push origin p01-prose-tool-call-leak-detector
```

Pushes a new branch to `WhitneyDesignLabs/WireClaw`. Does NOT trigger any notification to Mario.

---

## Step 2: File the issue

```bash
gh issue create --repo M64GitHub/WireClaw \
  --title "LLM response parser silently passes prose-leaked tool calls to history" \
  --body-file /mnt/c/Users/homet/Documents/WireClaw/sync/drafts/p01_issue.md
```

Note the absolute path to the body file (lesson from P05: relative paths can resolve unexpectedly depending on cwd at gh-command time). `gh` will return the issue URL — note the issue number.

---

## Step 3: WAIT for Mario's response

Same etiquette as P05 prep:

- Could be hours, days, or weeks. Mario is single-maintainer on a small project.
- Don't open the PR before he engages — that's the etiquette violation we're explicitly avoiding.
- Acceptable response patterns from Mario:
  - "Yes, send a PR" → proceed to step 4
  - "I think the current behavior is fine because X" → close conversation politely, don't argue
  - "Could you also do Y while you're at it?" → judgment call; small Y can be added to the PR, large Y deserves its own issue
  - "This is too much code for what it does" → consider splitting into v1 (XML+fenced only) and v2 (naked-JSON addition) as separate PRs
  - Silence > 2 weeks → polite "any thoughts on this?" comment is fine, then more silence is fine
- Code/Cowork should be re-engaged when Mario responds, NOT before.

---

## Step 4: Update the PR draft with the issue number

Edit `sync/drafts/p01_pr.md` and replace `<ISSUE_NUMBER>` with the actual number from step 2. Save.

---

## Step 5: Create the PR (only after Mario engages positively)

```bash
gh pr create --repo M64GitHub/WireClaw \
  --base main \
  --head WhitneyDesignLabs:p01-prose-tool-call-leak-detector \
  --title "Detect prose-leaked tool calls to prevent silent command drop" \
  --body-file /mnt/c/Users/homet/Documents/WireClaw/sync/drafts/p01_pr.md
```

`gh` returns the PR URL. Note for the worklog.

---

## Step 6: Update PATCHES.md status row

```
| P01 | drafted → filed (issue #N) → PR open (#M) → ... | ... |
```

Per HANDOFF.md, this is the canonical state — don't track patch status in chat history.

---

## Step 7: Respond to PR review

If Mario requests changes, push follow-up commits to `p01-prose-tool-call-leak-detector` (they automatically appear in the PR). Don't squash unless asked. If Mario closes without merging, that's also OK — the patch lives on in `WhitneyDesignLabs/WireClaw`.

If Mario asks for the patch to be split (e.g., XML/fenced detection in one PR, naked-JSON in a follow-up), the v1 + v2 commits can be reconstructed from local history at `b85c2b9` + `b6280eb` — they were squashed for the upstream PR but the originals are preserved.

---

## Rollback / clean-up if you change your mind before pushing

```bash
git checkout main
git branch -D p01-prose-tool-call-leak-detector
```

Local branch goes away; nothing was sent to GitHub.

---

## What Code DID NOT do this round

- Did NOT push to origin
- Did NOT file the issue
- Did NOT open the PR
- Did NOT touch `bench/fork/PATCHES.md`

All external actions are gated on Scott's explicit go-ahead per `to_code.md`, AND on P05 (#12) being resolved first.
