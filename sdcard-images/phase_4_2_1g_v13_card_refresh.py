#!/usr/bin/env python3
"""Phase 4.2.1.G.G stage 1: refresh v1.3 model card with superseded note.

Uploads only README.md to the existing v1.3 repo. Does NOT touch the
adapter or other artifacts. v1.3 remains a discrete release; the card
is updated to point readers at v1.3.1.
"""
from __future__ import annotations
import argparse, sys
from pathlib import Path

ROOT     = Path("/mnt/c/Users/homet/Documents/WireClaw")
CARD_SRC = ROOT / "bench/fork/lora/hf-publish/v1.3-README.md"
REPO_ID  = "WhitneyDesignLabs/wireclaw-agent-v1.3-lora"
COMMIT_MSG = "Refresh model card: superseded-by-v1.3.1 banner + cross-links"


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


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not CARD_SRC.exists():
        sys.exit(f"FATAL: card source missing: {CARD_SRC}")

    if not args.dry_run and not have_token():
        sys.exit("FATAL: no HuggingFace token found. Run `hf auth login` first.")

    size = CARD_SRC.stat().st_size
    print(f"-- refresh card {REPO_ID} (README.md, {size:,} bytes)")

    if args.dry_run:
        print("DRY RUN — not uploading")
        return 0

    from huggingface_hub import HfApi
    api = HfApi()
    api.upload_file(
        path_or_fileobj=str(CARD_SRC),
        path_in_repo="README.md",
        repo_id=REPO_ID,
        repo_type="model",
        commit_message=COMMIT_MSG,
    )
    print(f"   DONE.  https://huggingface.co/{REPO_ID}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
