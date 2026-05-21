#!/usr/bin/env python3
"""Phase 4.2.1.G.G stage 1: publish wireclaw-agent-v1.3.1-lora to HuggingFace.

Mirrors the v1.3 upload pattern. Stages just the canonical adapter
artifacts (no checkpoint dirs, no .gguf). Target HF repo:
WhitneyDesignLabs/wireclaw-agent-v1.3.1-lora.
"""
from __future__ import annotations
import argparse, shutil, sys
from pathlib import Path

ROOT     = Path("/mnt/c/Users/homet/Documents/WireClaw")
SRC_DIR  = ROOT / "bench/fork/lora/training/output/wireclaw-v1.3.1-brev"
CARD_SRC = ROOT / "bench/fork/lora/hf-publish/v1.3.1-README.md"
STAGE    = ROOT / "bench/fork/lora/hf-publish/_staging-v1.3.1"
HF_ORG   = "WhitneyDesignLabs"
HF_REPO  = "wireclaw-agent-v1.3.1-lora"
REPO_ID  = f"{HF_ORG}/{HF_REPO}"
COMMIT_MSG = (
    "Initial release: wireclaw-agent v1.3.1 LoRA adapter\n\n"
    "Targeted regression patch on v1.3. Harm-citation Article 3/12 "
    "specificity recovered to 6/6 (exceeds v1.1 baseline). Truth_uncertainty "
    "temp=0 partial recovery (0/4 -> 2/4). First chip-side model bump in "
    "project history: ESP32-C6 fleet being promoted v1.1 -> v1.3.1 at "
    "publication time. See README for the full iteration trail and the "
    "documented new authorization regression."
)
INCLUDE = [
    "adapter_model.safetensors",
    "adapter_config.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "chat_template.jinja",
    "training-config.yaml",
    "training-log.json",
]


def have_token():
    try:
        from huggingface_hub import get_token
        if get_token():
            return True
    except ImportError:
        pass
    for p in (Path.home() / ".cache/huggingface/token",
              Path.home() / ".huggingface/token"):
        if p.exists() and p.read_text().strip():
            return True
    return False


def stage_files():
    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    print(f"-- staging into {STAGE}")
    for fn in INCLUDE:
        src = SRC_DIR / fn
        if not src.exists():
            sys.exit(f"FATAL: missing {src}")
        shutil.copy2(src, STAGE / fn)
        print(f"  {fn}  ({src.stat().st_size:,} bytes)")
    shutil.copy2(CARD_SRC, STAGE / "README.md")
    print(f"  README.md  ({CARD_SRC.stat().st_size:,} bytes, from {CARD_SRC.name})")
    total = sum(p.stat().st_size for p in STAGE.iterdir() if p.is_file())
    print(f"-- {sum(1 for p in STAGE.iterdir() if p.is_file())} files / {total:,} bytes total")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.dry_run and not have_token():
        sys.exit("FATAL: no HuggingFace token found. Run `hf auth login` first.")

    stage_files()

    if args.dry_run:
        print("DRY RUN — not creating repo or uploading")
        return 0

    from huggingface_hub import HfApi, create_repo
    api = HfApi()
    print(f"\n-- create_repo {REPO_ID} (exist_ok=True)")
    create_repo(repo_id=REPO_ID, repo_type="model", exist_ok=True)
    print("   ok")

    print(f"\n-- upload_folder {STAGE} -> {REPO_ID}")
    api.upload_folder(
        folder_path=str(STAGE),
        repo_id=REPO_ID,
        repo_type="model",
        commit_message=COMMIT_MSG,
    )
    print(f"   DONE.  https://huggingface.co/{REPO_ID}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
