#!/usr/bin/env python3
"""Phase 4.1.2 Step 7: upload WireClaw Agent v1.1 LoRA to HuggingFace.

Prep + execution driver. Idempotent:
1. Stage the adapter into a clean dir (extract the tarball, substitute
   the README placeholder).
2. Create the model repo on HF if it does not exist.
3. Upload the staged folder as a model repo.

REQUIRES: `hf auth login` (interactive, with a write-scope token) must
have been run prior. (The old `huggingface-cli login` is deprecated;
`hf auth login` is the current command. Same backing token store.) The
script checks token presence first and aborts cleanly if missing.

DRY RUN: `python3 phase_4_1_2_hf_upload.py --dry-run`
LIVE   : `python3 phase_4_1_2_hf_upload.py`
"""
from __future__ import annotations
import argparse, json, os, re, shutil, subprocess, sys, tarfile
from pathlib import Path

ROOT       = Path("/mnt/c/Users/homet/Documents/WireClaw")
TARBALL    = ROOT / "bench/fork/lora/training/output/wireclaw-v1-adapter.tar.gz"
CARD_SRC   = ROOT / "bench/fork/lora/hf-publish/README.md"
STAGE      = ROOT / "bench/fork/lora/hf-publish/_staging"
HF_ORG     = "WhitneyDesignLabs"
HF_REPO    = "wireclaw-agent-v1.1-lora"
REPO_ID    = f"{HF_ORG}/{HF_REPO}"
COMMIT_MSG = "Initial release: wireclaw-agent v1.1 LoRA adapter (Project Opengates)"


def have_token():
    # Modern huggingface_hub (>=0.19): top-level `get_token`. Older versions
    # had `HfFolder.get_token`. Fall back to reading the token file directly.
    try:
        from huggingface_hub import get_token
        if get_token():
            return True
    except ImportError:
        pass
    try:
        from huggingface_hub import HfFolder
        if HfFolder.get_token():
            return True
    except Exception:
        pass
    # Last-resort filesystem check (token store can move across versions).
    for p in (Path.home() / ".cache/huggingface/token",
              Path.home() / ".huggingface/token"):
        if p.exists() and p.read_text().strip():
            return True
    return False


def stage_files():
    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    print(f"-- extracting {TARBALL.name} to {STAGE} --")
    with tarfile.open(TARBALL, "r:gz") as tf:
        tf.extractall(STAGE)
    # tarball expands to {STAGE}/wireclaw-v1-brev/...  -- flatten one level
    sub = next(p for p in STAGE.iterdir() if p.is_dir())
    for child in sub.iterdir():
        child.rename(STAGE / child.name)
    sub.rmdir()
    # Substitute README placeholder
    card = CARD_SRC.read_text(encoding="utf-8")
    card = card.replace("<YOUR-HF-USER>", HF_ORG)
    (STAGE / "README.md").write_text(card, encoding="utf-8")
    # Inventory
    files = sorted(STAGE.rglob("*"))
    print(f"-- staged {sum(1 for f in files if f.is_file())} files --")
    total = 0
    for f in files:
        if f.is_file():
            sz = f.stat().st_size
            total += sz
            print(f"   {f.relative_to(STAGE)}  ({sz:,} bytes)")
    print(f"   total: {total:,} bytes")


def upload(dry_run: bool):
    from huggingface_hub import HfApi, create_repo
    api = HfApi()
    print(f"-- ensuring repo {REPO_ID} exists --")
    if dry_run:
        print("   DRY RUN: would call create_repo(repo_id, repo_type='model', exist_ok=True)")
    else:
        create_repo(repo_id=REPO_ID, repo_type="model", exist_ok=True)
        print("   ok")
    print(f"-- uploading {STAGE} -> {REPO_ID} --")
    if dry_run:
        print(f"   DRY RUN: would upload_folder folder_path={STAGE} repo_id={REPO_ID}")
        return
    api.upload_folder(
        folder_path=str(STAGE),
        repo_id=REPO_ID,
        repo_type="model",
        commit_message=COMMIT_MSG,
    )
    print(f"   uploaded.  https://huggingface.co/{REPO_ID}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true",
                    help="Stage files and print what would happen; do not call HF API.")
    args = ap.parse_args()

    if not TARBALL.exists():
        sys.exit(f"FATAL: adapter tarball not found at {TARBALL}")
    if not CARD_SRC.exists():
        sys.exit(f"FATAL: model card not found at {CARD_SRC}")

    if not args.dry_run and not have_token():
        sys.exit("FATAL: no HuggingFace token found. Run `hf auth login` first.")

    stage_files()
    upload(args.dry_run)
    print("\nDONE.")


if __name__ == "__main__":
    main()
