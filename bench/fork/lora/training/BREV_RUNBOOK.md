# Phase 3.3.2 — Brev Training Execution Runbook

**Target:** Train `wireclaw-agent:v1.1` LoRA adapter on H100 80GB at Brev.
**Budget:** ~$3-5 total (instance ~45-60 min × ~$3/hr).
**Wall time end-to-end:** ~75-90 min including upload/download/post.

Phase boundaries are marked with **🛑 STOP — tell Cowork** so we
checkpoint at each significant cost or risk inflection.

---

## Phase 0 — Pre-flight (workstation, no instance yet)

### 0.1 Confirm training bundle ready

```bash
# In WSL on the workstation
cd /mnt/c/Users/homet/Documents/WireClaw
ls -la bench/fork/lora/training-data/wireclaw-v1-train.jsonl
ls -la bench/fork/lora/training-data/wireclaw-v1-val.jsonl
ls -la bench/fork/lora/training-data/manifest.json
ls -la bench/fork/lora/training/train.py
ls -la bench/fork/lora/training/configs/brev.yaml
```

Expect: all five files present, train ~5-15 MB, val smaller.

### 0.2 Confirm HF_TOKEN loads

```bash
set -a && . /mnt/c/Users/homet/Documents/WireClaw/Secrets.txt && set +a
echo "${HF_TOKEN:0:6}... (length ${#HF_TOKEN})"
```

Expect: `hf_... (length 37)` or similar.

🛑 **STOP** — confirm 0.1 + 0.2 pass before provisioning the instance. Tell Cowork "Phase 0 done."

---

## Phase 1 — Provision Brev instance (Brev web UI)

You already have H100 selected. Verify these settings before launching:

- **GPU:** 1× H100 80GB
- **vCPUs / RAM:** Brev's default for H100 is fine (typically 16 vCPU / 200GB RAM); we won't bottleneck on either
- **Disk:** **at least 100 GB** (model weights ~30GB + dataset + outputs + cache)
- **Image:** Brev's default deep-learning AMI (PyTorch + CUDA preinstalled is ideal; if Brev offers "PyTorch 2.x + CUDA 12.x" pick it)
- **Spot vs on-demand:** Spot is fine; training is short and resumable
- **Auto-stop:** Set to 1 hour idle. We won't be idle long.

**Launch the instance.** Wait for status = Running.

Brev should give you an **SSH command** that looks like:

```
ssh brev@<instance-id>.brev.dev -p <port>
```

Or it might use `ssh user@<ip>`. Brev's UI shows the exact command for your instance.

### 1.1 First SSH

```bash
# In WSL, paste Brev's SSH command. Accept fingerprint if prompted.
ssh brev@<instance-id>.brev.dev -p <port>
```

Once connected, verify:

```bash
nvidia-smi   # confirms H100 is visible
uname -a     # Linux kernel info
python3 --version
nvcc --version  # CUDA toolkit version
df -h /      # confirms enough disk
```

Expect: H100 80GB shown in nvidia-smi, Python 3.10+, CUDA 12.x.

🛑 **STOP** — paste the `nvidia-smi` output to Cowork. Tell me the disk space too. Don't proceed if any of these look off.

---

## Phase 2 — Instance environment setup (on the Brev instance)

These commands run on the Brev instance (you're SSH'd in).

### 2.1 Install Python dependencies

```bash
# On the Brev instance
pip install -U pip
pip install -U \
    torch \
    transformers \
    peft \
    trl \
    accelerate \
    bitsandbytes \
    datasets \
    sentencepiece \
    protobuf \
    pyyaml
```

Versions don't need pinning — Brev's image is recent enough that the
latest PyPI versions should work together. If something fails, paste
the error to Cowork.

### 2.2 Verify GPU is usable from Python

```bash
python3 -c "
import torch
print(f'torch {torch.__version__}')
print(f'cuda available: {torch.cuda.is_available()}')
print(f'cuda device: {torch.cuda.get_device_name(0)}')
print(f'memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB')
"
```

Expect: H100, 80GB, cuda available.

### 2.3 HuggingFace auth

```bash
# Two paths — pick one
# Option A: env var (simpler for one-off)
export HF_TOKEN='<paste your hf_... token here>'

# Option B: persistent login (one-time setup, then no env var needed)
# huggingface-cli login
# (paste token, "y" to git credential)
```

Test that the gated model is accessible:

```bash
python3 -c "
import os
from huggingface_hub import HfApi
api = HfApi(token=os.environ.get('HF_TOKEN'))
# Just check we can see the model metadata
info = api.model_info('meta-llama/Llama-3.1-8B-Instruct')
print(f'Access OK: {info.modelId}')
"
```

Expect: `Access OK: meta-llama/Llama-3.1-8B-Instruct`.

🛑 **STOP** — confirm Phase 2.1, 2.2, 2.3 all pass. Paste the GPU verify output and the HF access OK to Cowork. Tell me "Phase 2 done."

---

## Phase 3 — Upload training artifacts

**Open a second WSL terminal on the workstation** (keep the SSH session in the first one alive). The scp commands below run from the workstation, not from the Brev instance.

### 3.1 Upload training script + configs + Modelfile template

```bash
# In workstation WSL (NOT the Brev SSH session)
cd /mnt/c/Users/homet/Documents/WireClaw

# scp the training/ directory to the Brev instance home
scp -P <port> -r bench/fork/lora/training \
    brev@<instance-id>.brev.dev:/home/brev/wireclaw-training/

# scp the training-data/ directory
scp -P <port> -r bench/fork/lora/training-data \
    brev@<instance-id>.brev.dev:/home/brev/wireclaw-training-data/

# scp SOUL constitution (referenced by Modelfile + nice to have for inspection)
scp -P <port> -r bench/fork/lora/training-data/constitution \
    brev@<instance-id>.brev.dev:/home/brev/wireclaw-training-data/constitution-copy/
```

Adjust `<port>` and `<instance-id>` to match Brev's SSH command for
your instance. If Brev uses `user@ip` format instead, scp uses the
same form: `scp -r LOCAL user@ip:REMOTE`.

### 3.2 Verify uploads on the Brev instance

Back in the Brev SSH session:

```bash
ls -la /home/brev/wireclaw-training/
ls -la /home/brev/wireclaw-training-data/
```

Expect: `train.py`, `configs/`, `wireclaw-v1-train.jsonl`,
`wireclaw-v1-val.jsonl`, `manifest.json`, etc. Files should be non-zero size.

### 3.3 Update config paths to instance paths

The `brev.yaml` config has paths relative to the workstation
layout. Quick edit on the Brev instance:

```bash
cd /home/brev/wireclaw-training

# Update config to use absolute paths on the instance
python3 << 'EOF'
import yaml
cfg = yaml.safe_load(open('configs/brev.yaml'))
cfg['train_file'] = '/home/brev/wireclaw-training-data/wireclaw-v1-train.jsonl'
cfg['val_file']   = '/home/brev/wireclaw-training-data/wireclaw-v1-val.jsonl'
cfg['output_dir'] = '/home/brev/wireclaw-training/output/wireclaw-v1-brev'
yaml.safe_dump(cfg, open('configs/brev.yaml', 'w'), default_flow_style=False)
print(yaml.safe_dump(cfg, default_flow_style=False))
EOF
```

🛑 **STOP** — paste the updated config contents to Cowork. Confirm
paths look right. Tell me "Phase 3 done."

---

## Phase 4 — Sanity-check before paying for the full run

The full training run takes ~30-45 min. Before that, do a 1-step dry
run to catch any "this immediately crashes" issues without burning
GPU time.

### 4.1 Quick: load base model + tokenize one example

```bash
cd /home/brev/wireclaw-training
python3 << 'EOF'
import json, torch
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig

# Load just the tokenizer first — fast
tok = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
print(f"Tokenizer loaded: vocab {tok.vocab_size}")

# Load first val example, apply chat template
ex = json.loads(open("/home/brev/wireclaw-training-data/wireclaw-v1-val.jsonl").readline())
rendered = tok.apply_chat_template(ex["messages"], tokenize=False)
tokens = tok.apply_chat_template(ex["messages"], tokenize=True)
print(f"First example tokens: {len(tokens)}")
print(f"First 200 chars: {rendered[:200]}")
EOF
```

Expect: tokenizer loads, ~600-1500 token count, render looks like Llama 3.1 chat format.

### 4.2 Quick: load model in 4-bit (this is the slow step)

```bash
python3 << 'EOF'
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)
print("Downloading + loading model (this takes 3-5 min)...")
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    quantization_config=bnb,
    device_map="auto",
)
print(f"Model loaded. GPU mem used: {torch.cuda.memory_allocated() / 1e9:.1f} GB")
print(f"Model dtype: {next(model.parameters()).dtype}")
EOF
```

Expect: download takes 3-5 min on first run (~15 GB), GPU mem ~5-7 GB
after loading 4-bit Llama 3.1 8B.

If this works, you're cleared for the full training run.

🛑 **STOP** — paste the output of 4.1 + 4.2 to Cowork. Tell me "Phase 4 done." Last cost-checkpoint before training launches.

---

## Phase 5 — Launch training

### 5.1 Use tmux so SSH disconnect doesn't kill training

```bash
# On the Brev instance
tmux new -s train
```

(If `tmux` isn't installed: `sudo apt install -y tmux`)

You're now inside a tmux session. If your SSH disconnects, training
keeps running and you can reattach with `tmux attach -t train`.

### 5.2 Launch

```bash
# Inside tmux, on the Brev instance
cd /home/brev/wireclaw-training

# Make sure HF_TOKEN is still in env (tmux inherits unless we re-export)
export HF_TOKEN='<paste again or source from a file you copied up>'

# Launch
accelerate launch \
    --config_file /dev/null \
    --num_processes 1 \
    train.py \
    --config configs/brev.yaml 2>&1 | tee training-stdout.log
```

The `tee` saves stdout to a file in addition to printing — useful for
post-mortem if anything weird happens.

### 5.3 What to watch

You should see (over ~30-45 min):

1. Model download progress (first run only, ~3-5 min)
2. Dataset loading (~10 sec)
3. PEFT model preparation
4. Training loop begins. Each step prints `loss: X.XX` every 10 steps
5. After each epoch: eval loss is computed and reported

**Healthy training signs:**

- Training loss starts ~2-4, drops to ~0.5-1.5 by end of epoch 1
- Eval loss tracks training loss (gap is fine; eval much higher means overfitting)
- GPU memory steady around 30-50 GB used out of 80 GB
- No `NaN` or `Inf` in loss
- No CUDA OOM errors

**Unhealthy signs (stop and ping Cowork):**

- Loss stuck at the same value for 50+ steps
- Loss goes negative or NaN
- Eval loss diverging up while training loss drops (overfitting — but 3 epochs shouldn't get that bad)
- CUDA OOM (would need to lower batch_size)
- Any uncaught exception

### 5.4 If you need to leave

Detach from tmux with `Ctrl-b d`. Training continues. Reattach later
with `tmux attach -t train`.

Don't close the Brev instance until training finishes and the adapter
is downloaded.

🛑 **STOP** — when training completes, paste the final loss numbers and any warnings/errors. Tell me "Phase 5 done."

---

## Phase 6 — Retrieve the LoRA adapter

After training completes (you'll see "Training completed" or similar):

### 6.1 Inspect output

```bash
# On the Brev instance
ls -la /home/brev/wireclaw-training/output/wireclaw-v1-brev/
```

Expect: `adapter_model.safetensors` (~50-150 MB), `adapter_config.json`,
tokenizer files, `training-config.yaml`, and maybe per-epoch
checkpoints. The adapter file is the prize.

### 6.2 Download adapter to workstation

**Back in the workstation WSL terminal** (not the Brev SSH):

```bash
cd /mnt/c/Users/homet/Documents/WireClaw

# Download the full output dir
scp -P <port> -r \
    brev@<instance-id>.brev.dev:/home/brev/wireclaw-training/output/wireclaw-v1-brev \
    bench/fork/lora/training/output/

# Also download the training log
scp -P <port> \
    brev@<instance-id>.brev.dev:/home/brev/wireclaw-training/training-stdout.log \
    bench/fork/lora/training/output/wireclaw-v1-brev/
```

### 6.3 Verify

```bash
ls -la /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/wireclaw-v1-brev/
```

Expect: adapter files + log present.

🛑 **STOP** — confirm adapter download succeeded. Tell me "Phase 6 done."

---

## Phase 7 — Terminate Brev instance

**Don't skip this.** Brev keeps billing until you explicitly stop the
instance.

In Brev's web UI: find the instance, click "Stop" or "Terminate"
(Terminate deletes; Stop pauses but you can resume — for one-off
training, Terminate is cleaner).

Confirm in the UI that the instance status is "Terminated" / "Stopped"
and you're no longer being charged.

🛑 **STOP** — confirm instance terminated. Tell me "Phase 7 done."

---

## Phase 8 — Post-training (workstation or azza)

This step is for after the adapter is back on the workstation. It can
happen now or be deferred — the adapter is the durable artifact, so
even if we pause here, nothing is lost.

The post-training pipeline is:

1. Merge LoRA adapter into base weights → produces a fp16 model
2. Convert merged fp16 to GGUF Q4_K_M (matches v1 quantization)
3. Build `wireclaw-agent:v1.1` Modelfile pointing at the GGUF
4. `ollama create wireclaw-agent:v1.1 -f Modelfile`
5. Smoke-test with `ollama run wireclaw-agent:v1.1`

**Cowork will write the Phase 3.3.3 directive for this post-training
pipeline once Phase 3.3.2 (this runbook) hands back clean.** Steps
1-4 are mostly mechanical and can run on the workstation in WSL or on
azza directly.

The key decision for Phase 3.3.3 is: workstation (slower disk, easier
to iterate) or azza (closer to where the model serves from, but
requires SSH-and-copy).

---

## Standing items / known caveats (carry into 3.3.3+)

- **Chip-side tool format compatibility:** Llama 3.1 emits `{"name", "parameters": "<json-string>"}`. Ollama normalizes to its own format before WireClaw consumes it. Should be transparent but worth a chat-test post-deployment.
- **Multi-tool runtime behavior:** Single-tool training relies on Ollama's tool-loop for chaining. Validate with a multi-step request post-deployment.
- **TRL API drift:** train.py introspects TRL signatures at runtime. If Brev's TRL version is significantly newer/older than expected, the introspection should adapt — but watch for warnings.
