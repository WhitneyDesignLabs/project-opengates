# WireClaw Fork — Shipping Mechanics Handoff

This document is the operational checklist for the agent (Claude Code, future Cowork session, or future Scott) that actually ships the patches in `patches/` to a real GitHub fork and upstream.

Read `PATCHES.md` first for the *what* and *why*. Read this for the *how*.

---

## One-time setup (Scott does these in a browser / shell)

These three steps are not automatable. Do them once, then everything else can be agent-driven.

### 1. Create the GitHub fork

Visit `https://github.com/M64GitHub/WireClaw` in a browser. Click **Fork** (top-right). Choose `WhitneyDesignLabs` (or whichever GitHub account/org you want as fork owner). Result: `https://github.com/WhitneyDesignLabs/WireClaw` exists, linked to upstream.

### 2. Authenticate `gh` on the workstation

In a Windows PowerShell or WSL shell on the workstation:

```
gh auth login
```

Choose GitHub.com → HTTPS → authenticate via browser. Persists across sessions; one-time only.

Verify:

```
gh auth status
```

Should show "Logged in to github.com as <you>". This is the credential that lets Claude Code open issues and PRs on your behalf.

### 3. Clone the fork locally

Pick a working directory (e.g., `C:\Users\homet\Documents\WireClaw-fork\` — kept separate from this project's `WireClaw\` workspace folder which is the *Cowork* working dir, not the source tree).

```
cd C:\Users\homet\Documents\
git clone https://github.com/WhitneyDesignLabs/WireClaw.git WireClaw-fork
cd WireClaw-fork
git remote add upstream https://github.com/M64GitHub/WireClaw.git
git fetch upstream
```

Result: working copy on `main`, with both `origin` (your fork) and `upstream` (Mario's repo) as remotes. Confirm with `git remote -v`.

---

## Per-patch shipping cycle

For each patch in `bench/fork/patches/PNN-*.md`, the agent runs through this sequence. **Branch per patch**, no batching.

### Step A: Prepare the issue (upstream patches only)

Etiquette: open an issue first, wait for maintainer acknowledgement, then submit the PR. Skip this step for fork-only patches (F-series).

```
cd C:\Users\homet\Documents\WireClaw-fork
gh issue create \
  --repo M64GitHub/WireClaw \
  --title "<title from patch md>" \
  --body-file <(cat << 'EOF'
<paste the "Problem" section from the patch md, plus a short
"Proposed fix" sentence, plus a "PR ready if you'd accept this" footer>
EOF
)
```

Or supply the body inline. The text to use is in the patch markdown's `## Problem` section. Don't paste the full diff in the issue — that goes in the PR.

After filing, wait. Don't open the PR until Mario responds. If he doesn't respond within ~2 weeks, a polite "any thoughts on this?" comment is fine.

### Step B: Create the branch

```
cd C:\Users\homet\Documents\WireClaw-fork
git checkout main
git pull upstream main      # stay current with upstream
git push origin main        # mirror to your fork
git checkout -b PNN-short-name
```

Branch naming: `PNN-short-name` (e.g., `P01-text-leak-detector`, `P05-serial-send-description`). One branch per patch.

### Step C: Apply the patch

Read `bench/fork/patches/PNN-*.md`. The patch file contains `## Diff` sections with the actual code changes. Apply them as edits to the source tree:

- File paths in the patch markdown are relative to the WireClaw repo root (e.g., `src/llm_client.cpp`, `data/system_prompt.txt`).
- Diffs are presented in unified-diff-like syntax (with `+` and `-` lines) but they're guidance, not literal patch input. Apply them manually via your editor or via Claude Code's Edit tool.
- After applying, **compile-check** with `pio run -e esp32-c6` to confirm no syntax errors. (Note: env name in `platformio.ini` is `esp32-c6`, NOT `esp32-c6-devkitc-1` — the latter is the board identifier, not the env name.) If you don't have PlatformIO locally, push the branch and let GitHub Actions catch it (if F01-CI is set up).

### PowerShell + esptool Windows quirk

When invoking `pio run -t upload` (or any direct `esptool.py`/`esptool.exe` call) from PowerShell on Windows, **set `$env:PYTHONIOENCODING = "utf-8"` first**. Without it, esptool's UTF-8 progress glyph (`█`) blows up Windows' default cp1252 encoding mid-write, the writer thread crashes, esptool blocks on a full stdout pipe, and the chip is left partially flashed. Re-flashing recovers (ESP32-C6 has USB bootloader fallback), but the first attempt eats time. Persistent fix:

```powershell
# Add to your PowerShell profile ($PROFILE) so it's always set:
$env:PYTHONIOENCODING = "utf-8"
```

Or just always prefix the upload command:

```powershell
$env:PYTHONIOENCODING = "utf-8"; pio run -e esp32-c6 -t upload
```

### Fresh-chip first flash — also run `-t uploadfs`

A chip flashed for the *first* time (no LittleFS yet) needs the `data/` partition populated once, in addition to the firmware. After the firmware upload succeeds, run:

```powershell
& "C:\Users\homet\AppData\Roaming\Python\Python314\Scripts\pio.exe" run -e esp32-c6 -t uploadfs --upload-port COMxx
```

Without this the chip boots with an empty filesystem and the captive portal cannot save config. Subsequent flashes of the same chip do **not** need `-t uploadfs` again — the filesystem persists across firmware updates unless you explicitly want to reset it. Finding from the 2026-05-15 pilot flash of the "Pilot"-labeled ESP32-C6.

### Step D: Commit

```
git add <files>
git commit
```

Use the commit message from the patch markdown's `## Apply order in the actual fork` section in PATCHES.md (multi-line; describes the change in a Mario-friendly tone).

Single commit per patch. If your edits are messy, `git add -p` to stage cleanly, or `git commit --amend` to consolidate. Reviewers hate "fix typo" follow-up commits inside a single-feature PR.

### Step E: Push and create PR

```
git push origin PNN-short-name
gh pr create \
  --repo M64GitHub/WireClaw \
  --base main \
  --head WhitneyDesignLabs:PNN-short-name \
  --title "<title>" \
  --body-file <(echo "<paste the patch md's \"## Upstream PR text\" section>")
```

PR title and body are pre-drafted in each patch markdown under `## Upstream PR text`. Lift them verbatim.

If Mario asked for changes in the issue thread, address them inline before opening the PR.

### Step F: Respond to review feedback

This is the **one step that doesn't automate well**. Reviewer comments need judgment — they're sometimes "do this," sometimes "why did you do that," sometimes "I'd rather you did the opposite." Read in the browser, decide, push follow-up commits to the same branch (they automatically land in the PR).

If Mario closes the PR without merging, that's also OK. The patch then lives only in `WhitneyDesignLabs/WireClaw`. Keep going.

---

## Fork-only patches (F-series)

Skip step A entirely. Steps B-F are the same except the PR (if any) is **WhitneyDesignLabs:fork-trunk** ← **WhitneyDesignLabs:FNN-branch** — i.e., merging into your fork's own main branch, not upstream.

For fast iteration on fork-only work, an alternative is to keep everything on a long-lived branch like `whitneydesignlabs-trunk` instead of merging to `main`, so `main` stays close to upstream and `whitneydesignlabs-trunk` accumulates the project-specific changes. Decision: pick a flow when you start the second fork-only patch.

---

## Suggested first sessions

Sequence the first three patches deliberately to build trust with the maintainer:

### Session 1: P05 (`serial_send` description)

Smallest patch. One-line description edit. Friendliest first contact.

Issue first, wait for Mario's response, PR second. Aim: get one merge under your belt. Even if Mario doesn't merge, you've established that you exist, you read the code carefully, and you contribute professionally.

### Session 2: P02 (prompt truncation fix)

Pure bug. Clean buffer-size growth. Comes with bench evidence (T11, T12 universally failing). High confidence Mario will accept this — it's an obvious bug nobody noticed.

### Session 3: P01 (text-leak detector)

Most valuable patch, biggest review surface. Worth doing third because by then Mario knows you. Comes with bench evidence (zero Mode A/C today, but quantifiable benefit when models that leak are tested).

After these three, P04 / P03 / P06 can ship in any order as you have time. They have varying levels of opinion-content; P03 (example-augmented tools) is the most "this is just my preference" and should be pitched accordingly.

---

## Working with Claude Code

When you want Claude Code to actually ship a patch, the prompt looks like:

> Ship patch P05 to upstream. Read `bench/fork/patches/P05-serial-send-description.md` for the change, the commit message, and the PR text. The fork is at `C:\Users\homet\Documents\WireClaw-fork`. Steps: (1) `gh issue create` against M64GitHub/WireClaw with the problem statement, (2) wait for me to confirm Mario responded positively, (3) when I give the go, create branch `P05-serial-send-description`, apply the edit, commit, push, and `gh pr create` against M64GitHub/WireClaw with the PR text from the patch markdown.

For fork-only patches (F-series):

> Apply patch F01 to my fork. Read `bench/fork/patches/F01-ollama-defensive-opts.md`. Work in `C:\Users\homet\Documents\WireClaw-fork`. Create branch `F01-ollama-defensive-opts`, apply all diffs, commit with the message from the patch markdown, push to `origin`. Do not open a PR to upstream — this stays in WhitneyDesignLabs/WireClaw.

The patch markdowns are designed to be enough context for Claude Code to execute end-to-end without needing additional explanation. If a patch markdown isn't precise enough, treat that as a bug in the patch doc and improve it.

---

## Status tracking

When a patch ships, update its row in `bench/fork/PATCHES.md`:

| ID | Status | File |
|---|---|---|
| P01 | drafted → **filed (issue #NN)** → **PR open (#MM)** → **merged** / **closed unmerged** | ... |

This is the canonical state. Don't track patch status in chat history (volatile).

---

## When upstream merges a patch

```
cd C:\Users\homet\Documents\WireClaw-fork
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

Your fork is now back in sync with upstream, with your merged change reflected in upstream's history. You can delete the local feature branch (`git branch -D PNN-short-name`).

If you've already applied F-series patches and they conflict with upstream's evolved code, resolve the conflicts and re-test. F-series live on your fork-only branch; periodic upstream merges are part of fork maintenance.
