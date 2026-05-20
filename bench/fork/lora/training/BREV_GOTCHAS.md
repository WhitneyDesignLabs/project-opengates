# Brev Training Gotchas — Lessons from the First Run

Reference for future LoRA training runs on Brev (v1.2+). The first run
(2026-05-17, wireclaw-v1.1) hit a dozen friction points; documenting
them so the next runs can skip past.

If you're starting a new training run, **work through this file
first** before opening BREV_RUNBOOK.md — the runbook tells you what to
do, this file tells you what to expect to break.

---

## Workstation-side gotchas

### 1. WSL has a separate password from Windows

`sudo` in WSL needs the Linux user password (set when WSL was first
installed), not the Windows login. If you don't remember it, reset
from a **Windows PowerShell** window (NOT WSL):

```powershell
wsl --list                              # find the distro name
wsl -d <DISTRO_NAME> -u root passwd scott
```

Set the new password twice. Done.

### 2. Multi-line paste into WSL-via-PowerShell mangles

When pasting multi-line commands into a WSL bash shell hosted in
Windows Terminal (or PowerShell directly), terminal line-wrap and
copy/paste behavior can:

- Merge consecutive commands onto one line
- Strip leading characters from lines
- Cause heredocs to misbehave

**Workarounds:**

- Maximize the terminal window before pasting (wider lines = fewer wraps)
- Paste one line at a time for anything important
- For long blocks: write to a file via heredoc on a known-good
  machine, then `scp` or `brev cp` the file in
- For commands with embedded secrets: use `read -s -p "Token: " VAR`
  to prompt interactively, paste secret at the prompt

### 3. Cowork-written files have NUL padding when overwritten with shorter content

Anthropic's Write tool, when overwriting an existing file with shorter
content, sometimes leaves the old bytes as NUL padding rather than
truncating. Symptoms:

- `ls -la` shows the old (larger) byte count
- `wc -c` agrees with `ls -la`
- Python text readers stop at the first NUL and report less content
- Result: confusing discrepancy where two byte counts disagree

**Cleanup:**

```python
data = open('file.md', 'rb').read()
nul_idx = data.find(b'\x00')
if nul_idx >= 0:
    open('file.md', 'wb').write(data[:nul_idx].rstrip() + b'\n')
```

**Detection:** if `ls -la` size and "real" content size disagree, do
the NUL check before trusting either.

---

## Brev CLI install gotchas

### 4. The Brev install script needs sudo but uses sudo's HOME

The documented install:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/brevdev/brev-cli/main/bin/install-latest.sh)"
```

installs to `/root/.local/bin/brev` (because sudo gives the script
root's HOME), and the PATH-update suggestion points to root's home
too — useless to your normal user.

**Fix immediately after install:**

```bash
sudo cp /root/.local/bin/brev /usr/local/bin/brev
brev --version    # verify
```

Now `brev` works from any user without sudo, no PATH gymnastics.

### 5. `brev login` defaults to NVIDIA NGC OAuth

Login flow opens a URL pointing at `api.ngc.nvidia.com`. That's
intentional — Brev is NVIDIA's brand now. Use the same email you
have on your Brev account (which may be different from the email
you have on huggingface, etc.).

---

## Instance environment gotchas

### 6. Ubuntu 23+ refuses `pip install` without `--break-system-packages`

You'll get "externally-managed-environment" errors otherwise. On an
ephemeral Brev instance, breaking the system Python is fine:

```bash
pip3 install --break-system-packages -U <packages>
```

For a long-term machine, use a venv instead.

### 7. Brev's H100 image doesn't include FlashAttention2

Stock attn_implementation `flash_attention_2` in your config will
hard-crash with `ImportError: FlashAttention2 ... doesn't seem to be
installed`. Two options:

- **Install it:** `pip3 install --break-system-packages flash-attn --no-build-isolation` — builds from source, 5-10 min, version-sensitive to torch/CUDA
- **Use SDPA instead:** edit your config: `attn_impl: sdpa`. Built into PyTorch 2.x, zero install, ~20-30% slower than FA2 on H100 (~5 min added to our 15-min run, acceptable)

For a first run where you want to validate the pipeline, **always use SDPA**. Install FA2 later for production speed if you have repeated long runs.

### 8. Modern `accelerate launch` rejects `--config_file /dev/null`

The legacy "use defaults" trick of pointing at /dev/null now throws
`FileNotFoundError`. Two fixes:

- Drop the flag entirely (uses accelerate's defaults from
  `~/.cache/huggingface/accelerate/`)
- Skip accelerate for single-GPU: just `python3 train.py --config ...`
  works fine because HuggingFace Trainer handles single-GPU dispatch
  via `device_map="auto"` on its own

For single-H100 LoRA training, **just use `python3` directly**. No
benefit from accelerate at this scale.

---

## API/library version gotchas

### 9. `transformers` 5.x changed `apply_chat_template(tokenize=True)`

In transformers 4.x, this returned a flat list of token IDs:

```python
ids = tok.apply_chat_template(messages, tokenize=True)  # → [128000, 128006, ...]
len(ids)  # → real token count
```

In transformers 5.x, it returns a `BatchEncoding` dict:

```python
result = tok.apply_chat_template(messages, tokenize=True)
# → BatchEncoding({'input_ids': [...], 'attention_mask': [...]})
len(result)  # → 2 (the two keys!)
len(result['input_ids'])  # → real token count
```

**This bit our diagnostic** (we thought tokenization was broken when
the real bug was `len()` of a BatchEncoding). SFTTrainer handles the
new return type internally, so training-time behavior is fine — just
your manual token-counting code needs adjustment.

**Safe manual count:**

```python
result = tok.apply_chat_template(messages, tokenize=True)
ids = result['input_ids'] if hasattr(result, 'get') else result
n_tokens = len(ids)
```

### 10. Llama 3.1 chat template rejects multi-tool assistant messages

```python
tok.apply_chat_template([
  {"role": "user", "content": "..."},
  {"role": "assistant", "content": "...", "tool_calls": [tc1, tc2]}  # ← FAILS
])
# TemplateError: This model only supports single tool-calls at once!
```

The official Llama 3.1 chat template enforces one tool_call per
assistant message. If your training data has multi-tool turns
(captured from sequential tool-loop on the chip), SFTTrainer will
crash on those examples.

**Fix at data-prep time:** filter out any example whose assistant
message has more than one tool_call. The chip's runtime behavior
(multi-tool sequences via Ollama tool-loop) is preserved at
inference even when training data is single-tool only.

For wireclaw-v1, this dropped 16 captured turns (2.3%) and forced
synthetic regeneration to ≤1 tool_call per example.

### 11. Major-version skew in the ML stack rolls forward fast

The first run installed:
- transformers 5.8.1 (major version bump from the 4.x Code's train.py was written against)
- TRL 1.4.0 (major version bump from 0.x)
- peft 0.19
- accelerate 1.13
- torch 2.12 + CUDA 13

These all worked together for us via train.py's `_filter_kwargs`
adapter pattern, but it was a near thing. Future runs may see another
major bump.

**Mitigation in train.py:** the script uses `inspect.signature` to
filter kwargs to whatever the installed class actually accepts. Both
`max_seq_length` AND `max_length` are passed; whichever the installed
TRL wants gets through. Same for `eval_strategy`/`evaluation_strategy`
and `tokenizer`/`processing_class`.

**If a future bump breaks this:** consider pinning to a known-good
combo:

```bash
pip3 install --break-system-packages \
  'transformers<5.0' \
  'trl<1.0' \
  'peft<0.20' \
  'accelerate<1.5'
```

---

## Constitution / data gotchas (caught earlier in Phase 3.2 but worth
recording)

### 12. The v1 Modelfile's "9 articles" were a SAP-era ancestor, NOT canonical SOUL.md

Article numbering and content had drifted from canonical SOUL.md
v0.2.0. v1.1 corrects via the two-tier constitution:

- `SOUL.md` — canonical, 25,860 bytes, all 26 articles full prose
- `SOUL-LOCAL.md` — 5,829 bytes, all 26 articles distilled — used as
  training-time system prompt
- `SOUL-CHIP.md` — 3,069 bytes, 15 operational articles — used as
  runtime chip system prompt (fits the 4095-byte cfg_system_prompt
  truncation limit with margin)

The other 11 articles (5, 6, 8-11, 17, 21-24) get baked into model
weights via training (every training example carries SOUL-LOCAL.md as
system context). At inference, the chip provides SOUL-CHIP.md and
the weight-baked behaviors fill in the rest.

### 13. Modelfile bakes do NOT modify weights

`wireclaw-agent:v1` was bit-identical to `llama3.1:8b` — the Modelfile
just configured the system prompt and parameters around the base
weights. **Train against the OEM `meta-llama/Llama-3.1-8B-Instruct`,
not against `wireclaw-agent:v1`.** Cleaner lineage for the
HuggingFace public release; bit-identical to v1 anyway since v1 had
no weight delta.

### 14. Synthetic example generators need the real tool list embedded

First synthetic-generation round produced 37 distinct invented tool
names (thermostat_set, gpio_set, etc.) because the generator prompt
didn't constrain to the real WireClaw toolset. **Always embed the
canonical tool list in the synthetic-example generator prompt with
explicit instruction "use ONLY these tools."** Regenerating to fix
this was $0.09 — cheap but unnecessary if caught upfront.

The canonical WireClaw tools (per Modelfile):
led_set, gpio_write, gpio_read, temperature_read, device_info,
device_list, device_register, sensor_read, actuator_set, file_read,
file_write, rule_create, rule_delete, rule_enable, rule_list,
serial_send, nats_publish, remote_chat, chain_create.

---

## HuggingFace gating gotchas

### 15. Llama 3.1 gate is a collection, not per-model

When you request access to one model in the Llama 3.1 collection (e.g.
`meta-llama/Llama-3.1-8B`), Meta approves access to all 17 models in
that collection — including `Llama-3.1-8B-Instruct`. The Instruct page
may show a stale "awaiting review" banner; check
**huggingface.co/settings/gated-repos** for source-of-truth approval
status.

### 16. HF_TOKEN scope "Read" is sufficient

Don't need "Write" or "Admin" tokens. Create a read-only token named
something memorable (`wireclaw-lora-training`) and add it to
`Secrets.txt`. Same token used for workstation diagnostics, Brev
instance training, and any future GGUF push to HF.

---

## Process / workflow gotchas

### 17. Set HF_TOKEN AND ANTHROPIC_API_KEY via `read -s -p` to avoid paste-secret-in-line issues

```bash
read -s -p "Paste token then Enter: " HF_TOKEN \
  && export HF_TOKEN \
  && echo "export HF_TOKEN='$HF_TOKEN'" >> ~/.bashrc \
  && echo "loaded: len=${#HF_TOKEN}"
```

The `-s` flag hides the token. Each Brev instance is ephemeral, so
writing the token to `.bashrc` is fine (instance disappears at
terminate).

### 18. Two-terminal pattern for upload workflows

For `brev cp` workflows, you need a workstation shell open
simultaneously with the `brev shell` SSH session. Open the second WSL
window on the workstation BEFORE `brev shell`-ing, so the cp step
later doesn't require re-entering the brev shell.

### 19. tmux is critical for training over flaky networks

The first run did NOT have training inside tmux (because of an earlier
launch error that bypassed the tmux session). If the SSH connection
had dropped mid-training, we'd have lost the run. **Standard practice:
ALWAYS launch training inside `tmux new -s train`, then `Ctrl-b d`
to detach.** Monitor with `tail -f <log>` from a fresh non-tmux shell.

The fact that our run completed without disconnect was luck, not
design.

### 20. Cost math for budget planning

H100 80GB on Brev (Nebius backend, Mäntsälä Finland in our case):
$3.58/hr LIST PRICE — but actual billing is far more favorable.

**Brev's billing model (confirmed 2026-05-17):** The hourly GPU rate
applies ONLY when the GPU is actively running compute. The rest of the
time (instance idle / setup / file transfers / SSH overhead) bills at
storage rates of pennies per hour. For wireclaw-v1.1 the entire ~75
min session cost **$0.36 total** — roughly 6 min of GPU-active time
plus ~70 min of idle/storage time.

**Implications for future runs:**

- **Don't terminate between training rounds during a development cycle.**
  An idle instance costs pennies/day. The deps, base model weights,
  dataset, and any cached HuggingFace downloads are preserved. Spinning
  up a fresh instance for each run costs 30 min of setup time you'd
  otherwise skip.

- **Per-training-run cost is dominated by the GPU-active duration:**
  - 9-min training run on H100 ≈ $0.50
  - Sanity-check model load (3-5 min GPU) ≈ $0.20
  - Idle/setup overhead ≈ free
  - Realistic per-run cost for iterations: $0.30-0.70

- **Multi-run iteration is cheap:** running 10 hyperparameter sweeps
  on the same instance costs ~$5-7, not the $30-50 the list rate
  suggests.

- **Terminate only when you're DONE with the project phase, not after
  each run.** Storage during a multi-day iteration cycle costs ~$0.50
  total. Re-provisioning costs you 30 min of setup.

---

## Quick reference — corrected launch sequence

For v1.2 onwards, the friction-free path:

```bash
# Workstation: bundle and ship
cd /mnt/c/Users/homet/Documents/WireClaw
tar czf /tmp/wireclaw-bundle.tar.gz bench/fork/lora/training bench/fork/lora/training-data
brev cp /tmp/wireclaw-bundle.tar.gz wireclaw-training1:~/wireclaw-bundle.tar.gz

# Brev instance: setup + train
brev shell wireclaw-training1
pip3 install --break-system-packages -U torch transformers peft trl accelerate bitsandbytes datasets sentencepiece protobuf pyyaml
read -s -p "Paste HF token then Enter: " HF_TOKEN && export HF_TOKEN && echo "export HF_TOKEN='$HF_TOKEN'" >> ~/.bashrc
cd ~ && tar xzf wireclaw-bundle.tar.gz
python3 -c "import yaml; cfg=yaml.safe_load(open('/home/ubuntu/bench/fork/lora/training/configs/brev.yaml')); cfg['attn_impl']='sdpa'; cfg['train_file']='/home/ubuntu/bench/fork/lora/training-data/wireclaw-v1-train.jsonl'; cfg['val_file']='/home/ubuntu/bench/fork/lora/training-data/wireclaw-v1-val.jsonl'; cfg['output_dir']='/home/ubuntu/bench/fork/lora/training/output/wireclaw-vN-brev'; yaml.safe_dump(cfg, open('/home/ubuntu/bench/fork/lora/training/configs/brev.yaml','w'), default_flow_style=False)"
tmux new -s train
# inside tmux:
cd /home/ubuntu/bench/fork/lora/training && python3 train.py --config configs/brev.yaml 2>&1 | tee /home/ubuntu/training-stdout.log
# Ctrl-b then d to detach. tail -f the log from a fresh shell to monitor.
```

That's the boiled-down version. ~10 commands total, no friction.

---

## Updates to make to BREV_RUNBOOK.md

After v1.1 deploys cleanly, update the canonical runbook with:

1. Drop `--config_file /dev/null` from the accelerate launch command.
2. Replace `flash_attention_2` with `sdpa` in the config template (or
   add an FA2-install step as Phase 2.4 with a clear "skip this for
   first run" caveat).
3. Add the `read -s -p` pattern for HF_TOKEN as the only token-input
   path (no more multi-line paste with embedded token).
4. Add the two-terminal pattern note to Phase 3.
5. Mandate `tmux new -s train` BEFORE launching training, not as an
   afterthought.
6. Reference this file from the runbook intro.
