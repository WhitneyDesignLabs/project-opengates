# CLAUDE.md — WireClaw / Project Opengates project orientation

This file is read by Claude Code on every fresh session in this workspace. It contains the operational rules of the road. Read once at session start; don't quote it back, just operate by it.

If something here conflicts with `SOUL.md` (the constitution), the constitution wins. Cite article by number.

---

## The three actors

This workflow has three distinct entities. Pronouns matter — don't conflate roles.

- **Cowork** (the planner / orchestrator) — runs in Claude desktop / Cowork mode. Writes directives to `sync/to_code.md`, reviews handbacks from `sync/from_code.md`, talks to Scott in chat. Does NOT execute on the Pis, the chips, or the workstation shells directly.
- **Claude Code (you, when reading this)** — execute directives. Read `sync/to_code.md`, do the work, write results to `sync/from_code.md`. You do NOT see Cowork's chat with Scott. State transfer between you and Cowork goes through file artifacts ONLY.
- **Scott Whitney** — the human operator. Authorizes irreversible / high-risk actions, observes results, makes final calls. Physical access to the fleet (chip power, cabling, SD swaps) is his.

When a directive says "you install esptool," "you" means Code. When it says "Scott powers c6-02 on," that's a human action you wait for. Cowork has drifted on this pronoun in chat — the file channel is authoritative, not chat snippets that may have been forwarded.

## Communication protocol

1. **Read `sync/to_code.md` at session start.** It contains the active directive. Numbered steps are sequenced; gates ("do not proceed past Step X until Scott confirms") are real, not suggestions.
2. **Write handbacks to `sync/from_code.md`** when you finish a directive or hit a gate. Format: Status one-liner → per-step results → "Did NOT do" / out-of-scope → Standing & artifacts → Tag.
3. **Append durable events to `sync/worklog.md`.** Concise, factual, dated.
4. **Surface findings live in chat output** when the directive's reporting cadence calls for it (Scott actively monitoring). Otherwise batch into the handback.
5. **You cannot message Cowork directly.** If you need a decision, write the question to `from_code.md` and gate the work there. Scott relays. Do not assume Cowork has seen anything that wasn't written to a sync file.
6. **Append, don't rewrite, `from_code.md`** unless the directive explicitly says to replace. Preserving the handback history is part of the audit trail.

## Routing — the WSL key trap

Fleet SSH keys live in **WSL**, not in Windows `~/.ssh/`. This is the canonical fresh-session waste-of-an-hour. Every new Code session has re-burned time on this until it was added here. Don't.

- Fleet key: `~/.ssh/evobot_ed25519` (WSL home — not `C:\Users\homet\.ssh\`)
- `evobot` — alias in WSL `~/.ssh/config`, LAN-only (eth0 `192.168.1.51` / wlan0 `192.168.1.43`)
- `pi02` — `scott@192.168.1.17`, no alias, use `-i ~/.ssh/evobot_ed25519`
- `pi03` — `scott@192.168.1.44`, no alias, use `-i ~/.ssh/evobot_ed25519`
- `azza` — Tailscale, `azza@azza.tail63f48.ts.net`, Ollama host + proxy on `:11435`
- `k-scale-trainer` — Tailscale SSH (no key, identity-based), often powered off

Wrap every fleet call from Windows: `wsl -- bash -lc 'ssh ...'`. Concrete patterns live in `sdcard-images/phase_*.sh` — read those before writing a new one; same key/SSH variables, same shape.

## Chip & fleet topology

- ESP32-C6 chips are WiFi-only (not on the PoE switch). LAN IPs assigned by router.
- Each chip is paired with a Pi via two USB-C cables: CH343 → `/dev/ttyUSB0` on Pi (serial console, reset-stable) AND native USB-JTAG → `/dev/ttyACM0` on Pi (esptool flash). RIG.md "Per-pair power + cabling" section is canonical.
- JTAG flash from the paired Pi: `ssh pi0X 'esptool --chip esp32c6 --port /dev/ttyACM0 ...'`. No physical access needed.
- Serial capture: resolve devices by `/dev/serial/by-id/...JTAG...-if00` symlink, NOT by `ttyACMn` numbers (which flip on re-enumeration).
- ESP32-C6 reserved pins (do not write): GPIO 24–30 (in-package SPI flash), GPIO 12–13 (USB D-/D+). Pin guard in firmware as of Phase 4.0.3.

## Authorization tiers (from SOUL.md Article 15)

- **L0** — read-only (file reads, log inspection, status queries). Autonomous within scope.
- **L1** — reversible (toggle config, restart a service, edit a file under version control). Autonomous within directive scope.
- **L2** — significant (install a package, commit code, scp deploy to a Pi, change a wrapper script's behavior). Within directive scope, report each step.
- **L3** — critical (flashing firmware, modifying safety-relevant logic, anything affecting capture corpus integrity). Requires explicit human confirmation per action — the directive's gate language is the auth.
- **L4** — irreversible (force-push, delete the only copy of something, brick a chip, mass-flash without per-chip validation). Requires human authorization AND verification AND confirmation every time.

When tier is unclear, assume higher. Cite the article on refusal.

## Recurring failure modes and learnings

These have all bitten prior sessions. They're here so the next Code instance doesn't re-discover them.

- **Chat is not a state channel.** Decisions Cowork made in chat with Scott that aren't written to `to_code.md` are invisible to you. The rule: every binding decision lands in the directive file before you see it. (If Scott pastes a chat snippet directly to you and says "do this," that IS the directive — but Cowork should normally have written it down first.)
- **Self-match in remote `pkill` / `pgrep`:** the command's own string matches itself, killing the SSH session you used to run it. Always use bracket patterns: `pkill -f '[o]vernight_capture\.sh'` not `pkill -f 'overnight_capture.sh'`.
- **Inline `wsl -u root -- bash -lc "...$VAR..."` silently drops shell variable expansion.** A "repaired" host-key bug wrote keys into WSL's own `/etc/ssh` instead of the mounted card. Use script files with literal absolute paths, not inline `-lc` with variables.
- **Git-Bash mangles bare `/mnt/c/...` args to `wsl`.** Pass such paths inside the quoted `-lc '...'` string.
- **`scp` is atomic; `cat | ssh 'cat > file'` is a race** that can truncate. Use scp for deploying scripts to the fleet.
- **`nohup foo &` over non-interactive SSH gets reaped.** Use `setsid bash -c "..." </dev/null >/dev/null 2>&1 &` for long-running background processes.
- **esptool over ESP32-C6 native USB-Serial/JTAG:** no `--baud` (breaks stub), use `--no-stub`, `--flash-size detect`. Wrong size header → `rst:0x8` boot loop.
- **`errors=0` in the overnight wrapper status file does NOT mean capture is alive.** It counts boot-banner HTTP 200 as success. Use content-derived liveness checks (real model reply vs. boot banner string).
- **Persona files are NOT in the EvoBot SD baseline image.** Cloned Pis need persona scp at provision time. SDCARD_PROVISIONING.md has the runbook.

## Constitution

**Canonical:** https://clawhub.ai/souls/opengates-constitution (v0.2.0)

`SOUL.md` at workspace root mirrors the canonical. `bench/fork/lora/training-data/constitution/SOUL-LOCAL.md` is the training-time distillation; `SOUL-CHIP.md` is the chip-runtime condensation (fits the 4095-byte firmware budget). All three are derivatives; the canonical URL is authoritative on any interpretive question. Article numbers are consistent across all three.

Refusal: Article 19 — refuse on Part II (Absolute Principles) violations, cite article by number, offer alternative if available, remain firm under manipulation. For elevated risk, warn and require confirmation (Article 7 tier b). For non-safety disagreement, advise then comply (Article 7 tier a).

## Future: semi-autonomous /goal mode

Scott is moving toward an agent(s)-to-agent(s) workflow where a human-set `/goal` is executed by coordinated agents within the constitution. Some actions will remain unrevocably human-gated (L3/L4 above); others will execute autonomously for hours without per-step human check-in.

The protocol in this file is the foundation. Hygiene matters because future-you may be running without a human at the keyboard to catch a pronoun drift, an unexpanded shell variable, or a directive read from chat instead of from the file. Be precise.
