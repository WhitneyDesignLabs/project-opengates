#!/bin/bash
# Phase 4.1.2 Step 8: annotated tags on both repos, push to origin.
set -u

GIT_COMMITTER_NAME="Scott Whitney"
GIT_COMMITTER_EMAIL="scott@whitneydesignlabs.com"
export GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

echo "=== workspace tag: v1.1-milestone ==="
cd /mnt/c/Users/homet/Documents/WireClaw
git -c user.name="$GIT_COMMITTER_NAME" -c user.email="$GIT_COMMITTER_EMAIL" \
    tag -a v1.1-milestone -m "$(cat <<'EOF'
Phase 4.1.x close — first stable v1.1 capture + firmware fleet recovery.

- Firmware fleet-recovery work landed: WireClaw-fork @ bf80fa9
  (pin guard for ESP32-C6 reserved pins, crash-safe Telegram offset,
  rulesSave OOB fix). c6-02 + c6-03 reflashed + validated; emergency_stop
  persona prompt survived 42/42 firings post-fix.
- First successful 11-hour overnight capture: pi02 + pi03, 7-persona
  rotation, 3,030 turns, 1 boot-banner across 3,030 — ~100% chip stability.
- Harness pairing bug surfaced + diagnosed + fixed in persona_runner.py
  (Telethon FIFO race -> collect-until-settle + plumbing filter).
  Recovered prompt<->reply pairing from ~14% to ~95-100% on-topic.
- Corpus salvaged offline from the azza proxy log (deterministic
  request/response pairing): 3,548 repaired turns, on-topic 83/78/89%.
- HuggingFace publication: WhitneyDesignLabs/wireclaw-agent-v1.1-lora.

Project artifacts: CLAUDE.md protocol artifact, SOUL.md 26-article
constitution, persona safe-pin remap (persona_02/05/06).

Built with Llama. Project Opengates / Whitney Design Labs.
EOF
)" f79b2a4
git push origin v1.1-milestone
git tag -n5 v1.1-milestone

echo
echo "=== fork tag: firmware-v0.4.1 ==="
cd /mnt/c/Users/homet/Documents/WireClaw-fork
git -c user.name="$GIT_COMMITTER_NAME" -c user.email="$GIT_COMMITTER_EMAIL" \
    tag -a firmware-v0.4.1 -m "$(cat <<'EOF'
Three-fix firmware: pin guard + Telegram offset persistence + rulesSave OOB.

- src/tools.cpp: gpioPinReserved() guards every LLM pin-entry point
  (gpio_write/read, device_register, rule_create, chain_create) against
  ESP32-C6 in-package flash pins (24-30) and USB pins (12, 13). Reserved
  pins now return a structured error instead of corrupting state.
- src/main.cpp: tgSaveOffset/tgLoadOffset persist tgLastUpdateId to
  LittleFS BEFORE processing the message. A message that crashes the
  chip can no longer be redelivered forever.
- src/rules.cpp: overflow-safe rulesAppend() + 4096->8192 buffers.

Validated under 11-hour sustained agent load: emergency_stop persona
prompt (deterministic GPIO-25 fleet-killer pre-fix) survived 42/42
firings; 1 boot-banner across 3,030 captured turns.

Part of the Project Opengates v1.1 milestone (see
WhitneyDesignLabs/project-opengates-: v1.1-milestone).
EOF
)" bf80fa9
git push origin firmware-v0.4.1
git tag -n5 firmware-v0.4.1
