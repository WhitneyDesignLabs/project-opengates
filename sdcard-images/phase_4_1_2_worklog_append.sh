#!/bin/bash
set -u
WL=/mnt/c/Users/homet/Documents/WireClaw/sync/worklog.md
ENTRY=$(mktemp)
cat > "$ENTRY" <<'WORKLOG'


## 2026-05-19 — Phase 4.1.1 corpus salvage + Phase 4.1.2 publication milestone

**The day in one line:** Diagnosed and fixed the harness pairing bug; salvaged the overnight corpus offline from the azza proxy log; published the project workspace + firmware fork + v1.1 LoRA adapter publicly under WhitneyDesignLabs.

**Phase 4.1.1 — corpus salvage (Path A).** The 3,030-turn overnight Telegram-side capture was scrambled at the prompt↔reply level (~14% on-topic) due to an uncorrelated-FIFO bug in `persona_runner.py`. Phantom-prompter hypothesis investigated and ruled out via chip-side `from_id` check (every incoming msg is the operator's account). Fix applied: collect-until-quiescence (SETTLE_S=5s) + plumbing filter. Validated on c6-02: LED/IP 100%, temp 75% (the temp "miss" is a genuine chip error-reply, correctly paired). Corpus re-paired offline from azza proxy log via `merge_corpus.merge_records_into_turns` (deterministic request/response anchoring): 8,542/8,544 records consumed, 3,548 turns, on-topic temp 83% / led 78% / ip 88%.

**Phase 4.1.2 — publication.** `PROJECT_STATUS.md` rewritten for current state (4.0.x post-mortem + 4.1.x stabilization + queued work + v1.1 residuals). Workspace git initialized, `.gitignore` covers secrets, build artifacts, SD images, training-data; secrets-grep on every staged diff. 4 commits + annotated `v1.1-milestone` tag pushed to https://github.com/WhitneyDesignLabs/project-opengates-. Fork CRLF cleanup + `.gitattributes` (LF pinning) + `firmware-v0.4.1` tag on `bf80fa9` pushed to WireClaw fork. LoRA adapter (84 MB safetensors + tokenizer + chat_template + training metadata) published as model at https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora under Llama 3.1 Community License.

**Code stops here per directive Step 9.** Next phase is Scott + Cowork big-picture review before any v1.3 training authorization.

### Tag

"2026-05-19 — corpus salvaged (14% → ~85% paired); workspace repo + firmware fork + HF LoRA adapter all public under WhitneyDesignLabs; v1.1-milestone + firmware-v0.4.1 annotated tags; project milestone complete."
WORKLOG
cat "$ENTRY" >> "$WL"
rm -f "$ENTRY"
echo "appended:"
tail -n 6 "$WL"
