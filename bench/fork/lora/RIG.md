# Data Collection & Training Rig — vision document

Scott's vision (2026-05-13): a self-contained AI data collection and training rig combining the project's compute, edge, and networking inventory into a physical lab. Currently at vision stage; commitments accrete as decisions get made. Living document — update as direction firms up.

## Why a rig

Phase 3 is corpus-capture-dominated wall-clock-wise. The capture infrastructure is currently conceptual: Pi 3s as synthetic-user agents driving ESP32-C6 chips, conversations logged centrally, classifier labeling via Claude API. Building it as a coherent physical artifact rather than scattered components on a workbench is operationally cleaner and architecturally more interesting.

The rig also extends the "what can we build big with how little" framing into the lab itself — purpose-built from dormant and modest-cost hardware, capable of running a months-long automated capture-train-eval loop with minimal operator attention.

## Components inventoried (as of 2026-05-13)

**Edge / chip layer:**
- 3x ESP32-C6 16MB modules — 1 in active service (board 1), 2 spare
- 6 more ESP32-C6 16MB modules on order (Scott, 2026-05-13)
- Future fleet size: 9 chips when delivery completes

**Compute layer:**
- GTX 1080 system ("azza", current Ollama host)
- GTX 1070 system ("k-scale-trainer", **prepped 2026-05-13** — Pascal QLoRA validated; see "GTX 1070 — training node" section below; powered down between Phase 3.3 runs)
- Spare NUC PCs (count and specs TBD)
- Scott's main workstation (relief target — offload long-running tasks)

**SBC layer:**
- 7x Raspberry Pi 3 (dormant)
- Possibly other Pi generations (TBD which models)

**Networking layer:**
- PoE switch (model TBD)
- Router (existing or rig-dedicated TBD)
- Cabling, mounts, etc. — TBD

**Test equipment:**
- TBD — Scott has misc that may be relevant

## Form factor — undecided

Two options Scott named:

**Open frame.** Cheaper, easier access for swapping components, simpler thermal management. Less portable. Looks like a homemade workbench layout with components mounted on a board / shelf.

**Rack-mounted.** Cleaner, scalable, easier to relocate as a unit. Requires rack hardware (2-post or 4-post). More upfront cost, less flexible for non-standard form factors (Pi 3s and ESP32s don't have natural rack form). May need rack-mount trays / Pi cluster cases.

**Decision deferred.** Cowork recommendation when asked: open frame for v1 of the rig — get the topology working, then re-form-factor if it earns rack treatment.

## Topology sketch (revised 2026-05-15 for the 3+1 topology)

```
[Router / WAN] --- [PoE Switch] --+-- 3x Driver Pi 3 (evobot + 2 more)
                                  |    each PoE-powered via HAT
                                  |
                                  +-- 1x Status-display Pi 3
                                  |    PoE-HAT + HDMI/LCD output
                                  |
                                  +-- (3x ESP32-C6 fleet — WiFi-attached to router;
                                  |    NOT switch ports — they're WiFi-only)
                                  |
                                  +-- (azza / 1080 — server location, not in rack;
                                  |    LAN-connected; persistent Ollama + proxy on :11435)
                                  |
                                  +-- (k-scale-trainer / 1070 — open-frame, adjacent
                                       to rack; on-tailnet, wakes for Phase 3.3)
```

ESP32-C6 boards are WiFi-only (no Ethernet) so they attach via the router's WiFi
rather than the PoE switch directly. Switch carries the wired Pi cluster + status
display + a wired uplink to the router and out to azza on the LAN.

**PoE HAT count revised from 7 to 4** ($25 × 4 = ~$100 — significantly less than
the original $175 7-Pi estimate). Acceptable cost; install at the 3.1.2 build-out
time.

The status display can be Ethernet-only or WiFi — its job is mostly inbound
(scrape proxy stats from azza, scrape chip stats from each chip's `/api/*`) so
either works. PoE HAT simplifies cabling either way.

## Roles per component (revised 2026-05-15)

- **ESP32-C6 active fleet (3 chips):** capture endpoints. Each on `wdl-v1` +
  `wireclaw-agent:v1` + its own Telegram bot. The chips themselves are
  identical-config; persona variety comes from the Pi-side rotation of
  persona modules across sessions (a chip might serve persona_01 one hour
  and persona_03 the next — the chip doesn't care, the corpus tagging tracks
  which persona drove which turn).
- **ESP32-C6 baseline (C6-01):** kept off-rack and undisturbed on `p11-test`
  + `wireclaw-agent:v1` so we can A/B against the active fleet whenever
  needed.
- **Driver Pi 3 cluster (3 Pis):** synthetic-user driver scripts. Each runs
  `persona_runner.py` via the overnight wrapper, paced to one persona module
  per session. The persona module is a CLI arg, so changing persona is just
  changing the wrapper's argument list.
- **Status-display Pi 3 (the 4th rack unit):** read-only consumer. Pulls
  proxy stats from `azza:~/wireclaw-corpus/`, scrapes per-chip `/api/*`
  endpoints, renders a live dashboard on an attached HDMI/LCD. Application
  TBD — see "Status-display node" below.
- **azza (GTX 1080):** Ollama inference host, persistent proxy on `:11435`,
  corpus accumulation under `~/wireclaw-corpus/`. Stays in its existing
  server location; only the LAN cable runs to the rack.
- **k-scale-trainer (GTX 1070):** Phase 3.3 training + Phase 3.4 eval host.
  Open-frame adjacent to the rack; on the tailnet; mostly powered-off
  between training cycles. Out-of-rack by design (Pascal heat + open-frame
  airflow + the trainer doesn't need to be in the same enclosure as the
  capture loop).
- **PoE switch:** wired hub. Powers the 4 Pis (3 drivers + 1 display) via
  HATs.
- **Router:** WAN + WiFi for the 3 active ESP32-C6 chips.
- **Spares (4 Pis, 6 chips):** uncommitted. Available for fleet expansion
  if `OLLAMA_NUM_PARALLEL=2` or a second-GPU inference host turns out to
  let us scale past the current 3-chip ceiling.

## Status-display node (the 4th rack unit) — application TBD

Pi 3 + small HDMI/LCD + PoE HAT in a rack-mount tray. Scrapes data; renders.
Possible apps (Scott's call — pick whatever's fun):

- **Live capture-rate dashboard.** Turns-per-hour gauge, label-distribution
  pie (clean / pseudo-prose / fabricated / contradictory), latest wrap-up
  scroll, per-persona breakdown, GPU duty-cycle bar. Probably a Flask +
  Chart.js page served from the Pi, full-screen Chromium on the LCD.
- **Raw serial-tail of one chip.** SSH over to the Pilot's COM monitor host,
  pipe to the LCD. Looks like the inside of a hacker movie. Lowest
  implementation effort.
- **Aggregate stats poster.** Bigger-print numbers: total conversations
  captured, hours running, classifier agreement rate, days until Phase 3.2.
  Less moving, more "current status" feel.
- **Some hybrid.** Top half live scrolling, bottom half stats. Or alternate
  views on a timer.

Reuses one spare Pi 3 + a cheap 7" or 10" HDMI/LCD (~$50-80 range). PoE-HAT
keeps it to one cable into the rack. Out of scope for Phase 3.1 ship-quality;
queue it as a Phase 3.1.5 "fun" build alongside (or after) the 3-chip scale-out.

## Power budget (rough, revised 2026-05-15 for the 3+1 topology)

In the rack:
- 4x Pi 3 @ ~3 W each: 12 W
- 3x ESP32-C6 @ ~1 W each: 3 W
- Status-display HDMI/LCD (TBD model): ~5-15 W
- PoE switch: ~10-20 W idle, more under load
- Router: ~10 W (or external — TBD)

Adjacent / out-of-rack:
- azza (GTX 1080): 250 W under inference load, 100 W idle
- k-scale-trainer (GTX 1070, mostly powered down): 200 W under training, 80 W idle, near-0 W asleep
- Spare PCs / NUC: 15-65 W when running

Estimated total under capture load: **200-350 W** (single 15 A 120 V circuit; one good UPS will cover it). The 3-active-Pi topology cuts in-rack power roughly in half vs. the original 7-pair plan.

## Per-pair power + cabling architecture (decided 2026-05-16)

Each Pi + ESP32-C6 pair runs as a self-contained power unit:

**Pi power:**
- *Interim:* one wall-wart 2.5 A micro-USB PSU per Pi. Three units total (plus a fourth for the status-display Pi when that build lands). Pi 3s are notoriously picky about PSU quality — verify each with `vcgencmd get_throttled` after a few minutes of load and reject any showing `0x50005`. **EvoBot's current wall-wart is the known-bad one** from the 2026-05-15 throttle observation; replace before sustained operation.
- *Near-term upgrade (Scott, queued):* a unified `+5 V` rail derived from a single ~19 A bench/industrial PSU. Terminates in multiple micro-USB pigtails for the Pis (and USB-C/A pigtails for the chips, replacing the per-pair Pi-USB scheme below if convenient). Probe the PSU's wires with a multimeter before commissioning. Mechanical concern: PSU + compute may need to live on different rack shelves due to depth, but that's a layout decision, not a blocker.

**ESP32-C6 power + serial:**
- *One USB-C cable, mandatory at runtime:* paired Pi's USB port → chip's **CH343 UART bridge port**. Delivers 5 V power AND exposes the chip's serial output as `/dev/ttyUSB0` on the Pi. The Pi can `cat /dev/ttyUSB0` (or systemd-tee it to a log) for ground-truth chip-side serial capture independent of the proxy stream.
- *Second USB-C cable, optional:* paired Pi's USB port → chip's **native USB-JTAG port** (`/dev/ttyACM0` on the Pi). Provides in-place reflash capability (`pio run -t upload --upload-port /dev/ttyACM0`) without unplugging the chip from the rack. Scott ordered these per-pair — wire both; the JTAG cable is a quality-of-life win at zero extra cost.

**Why not dedicated USB PSU for the chips:** considered but rejected for 3.1.2. Pi 3 USB ports comfortably supply ESP32-C6's ~250 mA peak draw, the per-pair power isolation is good enough at 3-chip scale, and using the Pi's USB keeps the cabling story simple (Pi sees chip, chip is powered by Pi — single "thing per pair"). The 19 A rail upgrade later subsumes both Pi and chip power; in the meantime, this is clean.

## Chip provisioning workflow (per-chip, one-time)

1. **Workstation (PIO toolchain):** plug the new chip's USB-JTAG port into the workstation. Code runs:
   - `pio run -e esp32-c6 -t upload --upload-port COM<x>` — firmware (`wdl-v1` branch).
   - `pio run -e esp32-c6 -t uploadfs --upload-port COM<x>` — LittleFS partition (the fresh-chip finding from the 2026-05-15 pilot; required only on first flash of a never-before-flashed chip).
2. **Captive portal (manual, ~5 minutes):** chip reboots into AP mode after the firmware flash. Connect a phone or laptop to the chip's WiFi hotspot; fill in WiFi SSID + password, Telegram bot token (the new bot for this chip), Ollama URL = `http://192.168.1.60:11435`, model = `wireclaw-agent:v1`.
3. **Smoke test on the workstation:** chip joins LAN, takes a DHCP IP. While the chip is still on the workstation, fire one prompt via Telegram and watch for a clean reply. Catches bot-token typos and Ollama-URL mistakes while you're still in front of a keyboard.
4. **Move to rack:** unplug both USB cables from workstation; carry the chip to its rack position; plug the CH343 cable into the paired Pi; optionally plug the JTAG cable into the same Pi (different USB port) for in-place reflash.
5. **Done.** Chip is on the LAN; any future config changes (Ollama URL, model, `cfg_use_modelfile_system`) happen via `/api/config` POST — no captive portal again.

## Open questions specific to the rig

(Added to OPEN_QUESTIONS.md too, but enumerated here for rig-focused context)

1. Open frame vs rack — when to commit
2. PoE delivery method for Pi 3s (HAT vs injector)
3. Pi cluster networking (WiFi to switch's wireless? Or wired via PoE HAT?)
4. Corpus storage layer (Postgres vs SQLite vs flat JSON files)
5. Whether ESP32 fleet uses single SSID or separate VLAN for capture isolation
6. Whether to add UPS for unattended overnight runs
7. NUC selection if more than one is wanted (specs, count)
8. Cable management strategy
9. Physical location (basement? Office?  shop?)
10. Whether to include a small monitor + KVM for direct console access vs SSH-only

## Status

Vision stage. No commitments beyond "this direction." All form factor, topology, and component decisions deferred. Document updated as decisions accrete.

Scott's signal-of-intent (2026-05-13): the rig is happening. Ground work for hardware juggling, connecting, configuring, testing is TBD. Six additional ESP32-C6 modules are on the way.

## GTX 1070 — training node — inventory & prep status (2026-05-13)

**Reachable as:** `k-scale-trainer` / tailnet `100.87.204.47` / LAN `192.168.1.39`, user `scott`, via **Tailscale SSH** (`RunSSH: true`). No SSH keys — tailnet identity auth.

### B1 inventory
- OS: Ubuntu 24.04.3 LTS (Noble), kernel 6.14.0-37-generic, x86_64
- CPU: Intel i5-4590 @ 3.30 GHz, 4 cores / 4 threads (no HT)
- RAM: 23 GiB total, ~20 GiB available, 8 GiB swap
- Disk: 218 GB root volume; **90 GB free** after stack+model+HF cache (HF cache 28 GB, venvs 7.8+5.7 GB)
- GPU: **NVIDIA GTX 1070, 8192 MiB VRAM (7.92 GiB usable), driver 580.95.05, compute capability 6.1 (Pascal / sm_61)**
- CUDA toolkit: none system-wide (PyTorch pip wheels bundle their own runtime)
- Python: 3.12.3 system; no conda

### B2 stack — TWO venvs (the Pascal-compat distinction is load-bearing)
- `~/lora-venv` — modern Unsloth stack. **Unusable on this GPU.** `pip install unsloth` pulled `torch 2.10.0+cu128` whose arch list is `sm_70…sm_120` — **no sm_61**. torch kernel test failed `cudaErrorNoKernelImageForDevice`. Kept for reference / future non-Pascal card.
- `~/lora-venv-pascal` — **the working one.** Pinned: `torch==2.4.1+cu121` (arch list includes sm_50/sm_60/sm_70+, runs on sm_61), `bitsandbytes==0.43.1`, `transformers==4.44.2`, `peft==0.13.2`, `trl==0.11.4`, `accelerate==0.34.2`, `datasets==2.21.0`, `rich`.

### B3 smoke test — **the load-bearing finding**

**VERDICT: the GTX 1070 CAN host an 8B rank-32 4-bit QLoRA — but NOT via Unsloth, and NOT with peft's default kbit-prep.**

| Attempt | Result |
|---|---|
| Modern stack (torch 2.10, Unsloth) | **FAIL** — torch dropped sm_61; `no kernel image` on any CUDA op |
| Pascal stack, `prepare_model_for_kbit_training` default | **FAIL** — OOM at prep (fp32 upcast of norms: +1.96 GB, only 1.34 GB free; 8B-nf4 base already 5.70 GB) |
| Pascal stack + lean prep + `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` | **PASS** — 15-step rank-32 QLoRA train, **peak VRAM 6.52 GB / 7.92 usable**, **1.30 s/step** @ seq-len 256 / batch 1, loss converged (1.87→0.02 on toy data) |

Working recipe (must reproduce for Phase 3.3):
- Load `meta-llama/Llama-3.1-8B`-class in 4-bit nf4 + double-quant, fp16 compute (~5.7 GB)
- **Skip** `prepare_model_for_kbit_training`. Instead: `config.use_cache=False`; `model.gradient_checkpointing_enable()`; `model.enable_input_require_grads()`
- LoRA r=32 α=64, target q/k/v/o/gate/up/down; `optim="paged_adamw_8bit"`, `fp16=True`, batch 1
- Env: `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`
- Reference script on box: `~/smoke_qlora2.py`

**Implications for PHASE3.md:** its assertion *"Unsloth fits 8B QLoRA rank 32"* is **wrong for this hardware** — Unsloth requires sm_70+ and its current release drops Pascal at the torch layer. Phase 3.3's framework must be **plain peft + bitsandbytes (pinned Pascal stack)**, not Unsloth. Headroom is thin (~1.4 GB at seq-len 256) — longer sequences / larger effective batch will need seq-len caps or gradient accumulation, and rank >32 may not fit. Validate real-corpus seq-len before committing a training config.

### B4 reachability
Tailscale SSH confirmed working from the Windows workstation (also on `WhitneyDesignLabs@` tailnet). **Caveat:** the tailnet ACL SSH rule is in **`action: "check"` mode** — Scott approved one session via browser URL; unattended reconnects re-prompt after the check period (default 12 h). For multi-hour unattended Phase 3.3 training, switch the ACL SSH rule to `action: "accept"` scoped to `k-scale-trainer` + user `scott` (Tailscale admin console). Tracked as a Phase 3.3 prerequisite.

### B5 power state
Box **powered down** post-prep (`sudo poweroff`) — no reason to idle ~80 W for weeks until Phase 3.3. To bring back: power on (physical/WoL), it auto-rejoins Tailscale; if outside the ACL check window, Scott re-approves one SSH session URL (or switch ACL to `accept` first).

## Pi cluster — pilot status (EvoBot / Pi #1, 2026-05-15)

**Reachable as:** `ssh evobot` **from WSL only** (alias + `~/.ssh/evobot_ed25519` live in WSL's `~/.ssh/config`, not Windows Git Bash). eth0 `192.168.1.51` (static, primary), wlan0 `192.168.1.43` (DHCP backup). **Not on Tailscale** (LAN only). All Code access to evobot must route through `wsl -- bash -lc 'ssh evobot ...'`.

- Hostname: `evobot`; user `scott` (uid 1000, groups incl. sudo/gpio/i2c/spi/dialout); **NOPASSWD sudo confirmed**
- OS: Raspbian GNU/Linux 12 (bookworm); kernel 6.12.47+rpt-rpi-v7; Python 3.11.2
- Resources: 4 cores, 921 MB RAM (~803 MB available), 54 GB free on SD
- **⚠️ Throttle flag `0x50005` — active undervoltage + currently-throttled (not just history).** Marginal PSU. Did not impact the D1–D3 light plumbing, but **a better Pi 3 PSU (official 2.5 A / 5 V or equivalent) must be procured before Phase 3.1 at-scale sustained capture runs** — undervoltage under sustained load risks SD corruption + clock throttling skewing capture timing.
- venv: `~/phase31-venv` (Python 3.11.2) — `requests 2.34.2`, `PyYAML 6.0.3`, pip 26.1.1. Telethon deliberately NOT installed (Phase 3.1 scale-up adds the synthetic-user driver).
- Deployed tree: `~/wireclaw-phase31/bench/fork/lora/` (rsync'd from workstation workspace — NOT git clone; the lora/persona files are Cowork workspace artifacts, absent from the `wdl-v1` fork branch). `personas/persona_01_basic.py` verified runnable on the Pi (battery summary + JSON serialise clean).
- State: **pilot stack deployed; persona_01_basic in place; no automated capture driver yet — Telethon comes in Phase 3.1 scale-up.**

## Cross-references

- `bench/fork/lora/PHASE3.md` — the workstream the rig supports (**NOTE: update Phase 3.3 framework from Unsloth → pinned peft+bnb per B3 finding above**)
- `OPEN_QUESTIONS.md` — Q14 (Pi networking), plus rig-specific items in this doc
- `PROJECT_STATUS.md` — high-level project state
