# SD card provisioning — durable runbook

How to clone an established Pi 3 driver SD card (EvoBot is the canonical
source) onto additional cards for fleet expansion. Reusable: every time the
capture fleet adds a Pi or a card fails in service, this is the procedure.

This doc captures the *what* and the *why*. The actual execution is normally
driven by Code under a `to_code.md` directive that walks the operator through
the card-swap prompts. The doc exists so the procedure isn't reinvented each
time, and so Code in a future fresh session has the conceptual model.

## When to use

- Adding new Pis to the capture fleet (3.1.2 brings the count from 1 to 3
  driver Pis; future rounds may add the status-display node, spare driver
  nodes, etc.).
- Replacing a failed SD card (consumer cards degrade under sustained-write
  duty cycles; an established driver-Pi card lasting more than a few months
  of overnight runs is not guaranteed).
- Bootstrapping a parallel capture lab in a different physical location.

## ⚠️ Known gap: persona files on the clone source image (2026-05-16)

The canonical EvoBot SD image was captured BEFORE personas 02-07 were
authored. The current clone source (`evobot-source-2026-05-16.img` or
similar) contains only `persona_01_basic.py` in
`~/wireclaw-phase31/bench/fork/lora/personas/`. A fresh clone using
the existing source image will **silently fail any wrapper run that
specifies `PERSONAS=` with a persona that isn't `persona_01_basic`** —
the runner exits on the first unknown persona module, and from the
operator's perspective the loop just stops producing Telegram activity.

**Symptom that's deceptive:** the first session in the rotation (which is
always persona_01 by round-robin position 0) succeeds. The wrapper's
status file ticks to `session=2` as the next iteration starts. Then the
runner fails to load `persona_02_*` and the loop dies. By the time the
operator notices, the status file looks like a stale "session=2 started"
record. This was the 3.1.3 Phase L incident on 2026-05-16 — pi02 and
pi03 both fell off this gap within minutes of L3 launch.

**Until this is fixed, fleet expansion needs an explicit persona-sync
step** between Phase 3 (write image to SD) and Phase 4 (boot + verify):

```bash
# After the new Pi is up and SSH-reachable, sync the current persona
# library from the workstation:
scp C:\Users\homet\Documents\WireClaw\bench\fork\lora\personas\persona_*.py \
    scott@<new-pi>.local:wireclaw-phase31/bench/fork/lora/personas/
```

**Two ways to close the gap properly** (queued as a Cowork follow-up):

1. **Re-capture the EvoBot SD image** after personas 02-07 are deployed on
   EvoBot. Captures-the-current-state pattern — the original Phase 1
   intent. Re-capture cost: ~15 min of Phase 1 effort plus the next clone
   write. Recommended if the persona library is stable.

2. **Add a persona-sync step to `clone_customize.sh`** that copies
   `bench/fork/lora/personas/*.py` from the workspace tree into the
   loop-mounted clone's
   `/home/scott/wireclaw-phase31/bench/fork/lora/personas/` directory.
   Future-proof: any persona added to the workspace is automatically
   baked into the next clone. Recommended for the long-term.

Pick whichever is cheaper. Until then, every Pi cloned must be
persona-synced before its wrapper sees PERSONAS pointing at anything but
`persona_01_basic`.

## When NOT to use

- Major OS version upgrades (Bookworm → next Debian). For those, a fresh
  install with Pi Imager + the documented setup steps is cleaner.
- When you need an *intentionally different* per-Pi software stack
  (different Python version, different deps, different persona scripts).
  Use Pi Imager fresh install instead.

## Requirements (one-time host setup)

1. **`usbipd-win`** on the Windows host. Microsoft-supported tool for
   passing USB devices through to WSL. Install once:
   ```powershell
   winget install --interactive --exact dorssel.usbipd-win
   ```
   Reboot if prompted.
2. **WSL with sudo** (Scott's existing setup; nothing to do).
3. **~10 GB free** on the Windows D drive (or wherever the workspace lives)
   for the captured `.img` files. Pishrunk images are ~5 GB each; we keep
   one canonical source image + per-clone customized copies.
4. **A USB SD card reader.** Any cheap reader works.
5. **Blank SD cards.** 32 GB+ minimum (the shrunk image expands to 16 GB
   typical). Recommended: endurance-class cards (SanDisk High Endurance or
   Samsung PRO Endurance) — consumer cards die fast under the overnight
   capture loop's write pattern.

## The four phases

### Phase 1 — Capture EvoBot's SD as a canonical image

One-time per "snapshot" of the driver Pi state. Captures whatever's currently
on EvoBot — venv contents, persona scripts, secrets file structure (but see
the secrets note below), WiFi credentials, scott user setup.

1. Code SSH to EvoBot: `sudo poweroff`. Wait ~30 s for clean shutdown
   (watch for the SSH session to drop and the LEDs to settle).
2. Operator (Scott) physically pulls the SD card from EvoBot, inserts it
   into a USB SD card reader, and plugs the reader into the workstation.
   Wait for Windows to register the new USB device.
3. Code (Windows PowerShell): `usbipd list` to find the bus-id of the SD
   reader. One-time per reader device: `usbipd bind --busid <X-Y>`.
4. Code: `usbipd attach --wsl --busid <X-Y>` — passes the USB device
   through to the WSL kernel.
5. Code (WSL): `lsblk` to confirm the SD card device path (typically
   `/dev/sdb` for a single external USB device; varies if other USB
   storage is attached). Sanity-check the device size matches the SD card
   capacity, NOT the workstation's internal drives.
6. Code (WSL): capture the image:
   ```bash
   sudo dd if=/dev/sdb \
           of=/mnt/c/Users/homet/Documents/WireClaw/sdcard-images/evobot-source-$(date +%F).img \
           bs=4M status=progress conv=fsync
   ```
   Will take 5–15 minutes depending on card size and reader speed.
7. Shrink the image (drops it from 32 GB to ~5 GB):
   ```bash
   sudo apt install -y pishrink   # one-time
   sudo pishrink.sh /mnt/c/Users/homet/Documents/WireClaw/sdcard-images/evobot-source-$(date +%F).img
   ```
8. Detach the USB device from WSL: `usbipd detach --busid <X-Y>` (from
   PowerShell).
9. Operator pulls the SD card from the reader, puts it BACK INTO EVOBOT,
   powers EvoBot on. EvoBot returns to normal duty.

The canonical image now lives at
`C:\Users\homet\Documents\WireClaw\sdcard-images\evobot-source-<DATE>.img`
and is the basis for any number of per-clone customizations.

### Phase 2 — Per-Pi customization via loop-mount (WSL-side)

For each new Pi we want to provision, Code makes a customized copy of the
source image. This avoids host-key clashes, hostname conflicts, IP
collisions, and accidental Telethon session collisions.

For each target hostname (e.g. `pi02`, `pi03`, `pi04`):

1. Code copies the source image:
   ```bash
   cp evobot-source-<DATE>.img <hostname>-<DATE>.img
   ```
2. Code loop-mounts the rootfs partition (partition 2 on a standard
   Raspbian image):
   ```bash
   sudo losetup -P /dev/loop0 <hostname>-<DATE>.img
   sudo mount /dev/loop0p2 /mnt/clone-rootfs
   ```
3. Edits to perform inside `/mnt/clone-rootfs`:
   - `/etc/hostname` → replace `evobot` with the new hostname.
   - `/etc/hosts` → change the `127.0.1.1   evobot` line to the new hostname.
   - `rm /mnt/clone-rootfs/etc/ssh/ssh_host_*` — SSH regenerates per-host
     keys on first boot if none exist.
   - `rm /mnt/clone-rootfs/etc/machine-id` and
     `rm /mnt/clone-rootfs/var/lib/dbus/machine-id` — systemd regenerates
     on first boot.
   - eth0 NetworkManager connection: switch from `method=manual` to
     `method=auto` (DHCP), remove the `addresses=` line. The Pi gets a
     DHCP IP on first boot; assign a static via post-boot SSH if desired.
     Path: `/etc/NetworkManager/system-connections/` — the eth0 connection
     file (name varies; the one with `interface-name=eth0`).
   - `rm /mnt/clone-rootfs/home/scott/.telethon-evobot.session*` — Telethon
     re-auths against this Pi's bot on first run; each clone gets its own
     session file.
   - `rm /mnt/clone-rootfs/home/scott/.overnight-capture.status*` and
     `rm /mnt/clone-rootfs/home/scott/overnight-capture.log` — stale state
     from EvoBot's history.
   - **Write a provenance file** to `/mnt/clone-rootfs/home/scott/SDCARD_PROVENANCE.md`
     containing:
     ```
     # SD card provenance
     Source:        evobot SD captured <ISO timestamp>
     Cloned to:     <hostname>
     Cloned at:     <ISO timestamp>
     Cleanup performed: hostname, machine-id, ssh host keys, eth0→DHCP, telethon session, stale logs
     Procedure:     bench/fork/lora/SDCARD_PROVISIONING.md
     ```
     So if this card ever falls into a future Cowork session's lap, the
     card knows its own history.
4. Sync + unmount:
   ```bash
   sync
   sudo umount /mnt/clone-rootfs
   sudo losetup -d /dev/loop0
   ```

The customized `.img` is now ready to write to a blank SD card.

### Phase 3 — Write the customized image to a blank SD

For each target Pi:

1. Operator inserts a blank SD card into the USB reader.
2. Code (PowerShell): `usbipd attach --wsl --busid <X-Y>`.
3. Code (WSL): `lsblk` to confirm the device path matches the blank card's
   size. **Triple-check the device path before dd-ing** — `dd` of the wrong
   device kills the workstation's drive.
4. Code (WSL):
   ```bash
   sudo dd if=<hostname>-<DATE>.img of=/dev/sdb bs=4M status=progress conv=fsync
   sync
   ```
   Takes 3–8 minutes per card.
5. Code (PowerShell): `usbipd detach --busid <X-Y>`.
6. Operator pulls the SD, labels it physically (sharpie on a sticker, etc.
   with `pi02 / 2026-05-16 / ...`), inserts it into the target Pi.

### Phase 4 — Boot + verify

1. With **EvoBot powered down** (to avoid IP / mDNS collisions if anything
   in cleanup got missed), operator powers on the target Pi.
2. Wait ~60 s for first boot (regenerates SSH host keys, machine-id,
   expands rootfs if pishrunk).
3. From the workstation: `ssh scott@<hostname>.local` (mDNS) or
   `ssh scott@<DHCP-assigned-IP>` (if mDNS doesn't resolve; find the IP
   via the router's DHCP lease table).
4. On the new Pi:
   ```bash
   hostnamectl                              # confirm new hostname
   cat /etc/machine-id                      # confirm fresh
   ls /etc/ssh/ssh_host_*                   # confirm regenerated (different fingerprints)
   ls ~/.telethon-evobot.session            # should NOT exist
   cat ~/SDCARD_PROVENANCE.md               # the breadcrumb we wrote
   ~/phase31-venv/bin/python ~/wireclaw-phase31/bench/fork/lora/persona_runner.py \
       --persona persona_01_basic --bot-username <this-pi's-bot> --dry-run
   ```
   Dry-run should print the persona's 10-prompt battery cleanly. If yes,
   the clone is fully functional.
5. Optionally set a static IP for the new Pi (`nmcli connection modify`
   commands; per-fleet convention).
6. Power EvoBot back on. Verify no IP / hostname conflicts on the LAN
   (`arp -a` from the workstation; ping each Pi by hostname).

## Secrets — what carries over, what doesn't

The cloned image *will* carry over EvoBot's `~/.wireclaw-secrets.env` —
which contains `TG_API_ID`, `TG_API_HASH`, and `TG_PHONE`. For a fleet
that uses the same Telegram user account driving multiple bots (the
recommended pattern), this is correct: each Pi authenticates as the
same Telegram user, runs its own Telethon session, talks to its own
chip's bot.

If you want a different Telegram user per Pi (for full isolation), you'd
need to:
- Register additional Telegram accounts (each needs a unique phone number).
- Generate new api_id/api_hash via my.telegram.org for each account.
- Per-Pi customization step: overwrite `~/.wireclaw-secrets.env` with that
  Pi's credentials.

Out of scope for the current 3-pair build-out — the shared-account pattern
is simpler and sufficient.

## Common failure modes

- **`usbipd attach` fails with permission denied:** run PowerShell as
  Administrator, or pre-`usbipd bind` once with admin privileges per
  device.
- **`dd` of the wrong device:** there is no recovery if you `dd` over the
  workstation's internal drive. Always `lsblk` and verify size + filesystem
  before `dd if=... of=/dev/sdX`.
- **Cloned Pi can't reach the LAN:** NetworkManager connection file's
  `method=auto` change wasn't applied cleanly, OR the file's filename was
  customised on the source and the loop-mount script edited the wrong
  file. Mount the card again, inspect `/etc/NetworkManager/system-connections/`.
- **SSH key warnings ("REMOTE HOST IDENTIFICATION HAS CHANGED"):** the
  cloned Pi has fresh host keys but the workstation's `~/.ssh/known_hosts`
  still has the old EvoBot fingerprint cached. Resolve with
  `ssh-keygen -R <hostname>` then re-connect.
- **mDNS resolution fails:** the new Pi may need 30-60 s post-boot for
  Avahi to publish. Try `ping <hostname>.local` in a loop; or find the
  DHCP-assigned IP via the router.

### Hard-won lessons (2026-05-16 pi02/pi03 build)

- **NO SSH on first boot — the unrecoverable one (FIXED in clone_customize.sh).**
  Removing `/etc/ssh/ssh_host_*` and trusting first-boot regen DOES NOT WORK
  on the EvoBot baseline: its `regenerate_ssh_host_keys.service` is the RPi
  run-once type that already self-disabled on EvoBot long ago. Result: clone
  boots with no host keys → `ssh.service` ExecStartPre `sshd -t` fails →
  sshd never starts → no SSH and (headless) no console = card-pull required.
  **Fix applied:** clone_customize.sh now GENERATES unique host keys per card
  at clone time (literal paths). Do not revert to remove-and-hope.
- **`/etc/machine-id` must be EMPTY, not absent.** `rm`-ing it did not trigger
  first-boot regeneration on this image (pi02 booted with it still missing).
  clone_customize.sh now truncates it to 0 bytes (the documented systemd
  first-boot-provisioning trigger).
- **`/etc/hosts` loopback line is `127.0.1.1 pitest`, not `evobot`.** The
  `s/evobot/$TARGET/` sed misses it → `sudo: unable to resolve host` warnings
  + possible service hiccups. clone_customize.sh now force-rewrites the
  `127.0.1.1` line to the target hostname regardless of prior value.
- **WSL shell-quoting trap (operator caution).** Multi-line
  `wsl -u root -- bash -lc "...$VAR..."` silently drops `$VAR`/`$(...)`
  expansion — an inline host-key "repair" generated keys into WSL's *own*
  `/etc/ssh` instead of the mounted card, looking successful but fixing
  nothing. Always run customization from the **script file**
  (`clone_customize.sh`, executed as `wsl -u root -- bash -lc "bash '/mnt/c/.../clone_customize.sh' <tgt>"`),
  never as ad-hoc inline multi-line `-lc` with variables. Verify with
  **literal absolute paths** (`/mnt/clone-rootfs/...`), never via `$R`.
- **Git-Bash mangles bare `/mnt/c/...` args to `wsl`.** Pass such paths
  *inside* the quoted `-lc '...'` string, not as bare arguments.
- **Pre-fix cards before first boot.** pi03 was host-key+machine-id+hosts
  fixed at the workstation before it ever booted → zero pull/repair cycles.
  Do this for all remaining fleet cards (clone_customize.sh now does it
  automatically; the 4 spares just need a normal clone+customize run).

## Cross-references

- `bench/fork/HANDOFF.md` — shipping mechanics (separate concern, but
  same operator).
- `bench/fork/lora/PHASE3.md` — Phase 3 plan; the 3-pair build-out is 3.1.2.
- `bench/fork/lora/RIG.md` — fleet topology; SD card replacement frequency
  is a long-term operational concern.
- `OPEN_QUESTIONS.md` Q14 — Pi cluster networking (PoE HAT vs DHCP vs static).
