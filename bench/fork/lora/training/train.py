#!/usr/bin/env python3
"""
wireclaw-v1 QLoRA SFT trainer.

Driven by `accelerate launch train.py --config <yaml>` so the same script
runs on Brev (H100/A100, bf16+FA2) and Pascal (GTX 10xx, fp16+sdpa). All
knobs come from the YAML config; nothing host-specific is hard-coded.

Contract: SFTTrainer consumes the messages-format JSONL (one
{"messages":[...]} object per line), applies the tokenizer's chat
template, trains a PEFT LoRA adapter on 4-bit (QLoRA) base weights, and
saves ONLY the adapter (+ tokenizer + a copy of the config) to
cfg["output_dir"].

TRL API note: across TRL versions the SFT knobs have moved
(`max_seq_length` -> `max_length`, `evaluation_strategy` ->
`eval_strategy`, messages auto-detection added in 0.9+). This script
probes the installed signatures at runtime and falls back, rather than
pinning a TRL version we cannot verify here (torch/trl are not installed
in the format-validation environment; they exist on the Brev image).
"""
from __future__ import annotations

import argparse
import inspect
import json
import os

import yaml


def _filter_kwargs(cls, kwargs: dict) -> dict:
    """Keep only kwargs the installed class actually accepts."""
    try:
        sig = inspect.signature(cls.__init__)
    except (TypeError, ValueError):
        return kwargs
    if any(p.kind == inspect.Parameter.VAR_KEYWORD for p in sig.parameters.values()):
        return kwargs
    allowed = set(sig.parameters) - {"self"}
    return {k: v for k, v in kwargs.items() if k in allowed}


def build_sft_config(SFTConfig, cfg: dict):
    """Construct SFTConfig tolerantly across TRL versions."""
    compute = cfg["compute_dtype"]
    candidate = dict(
        output_dir=cfg["output_dir"],
        num_train_epochs=cfg["epochs"],
        per_device_train_batch_size=cfg["batch_size"],
        gradient_accumulation_steps=cfg["grad_accum"],
        learning_rate=float(cfg["learning_rate"]),
        lr_scheduler_type=cfg.get("lr_scheduler", "cosine"),
        warmup_ratio=cfg.get("warmup_ratio", 0.03),
        weight_decay=cfg.get("weight_decay", 0.01),
        bf16=(compute == "bfloat16"),
        fp16=(compute == "float16"),
        logging_steps=cfg.get("logging_steps", 10),
        save_strategy="epoch",
        report_to="none",
        seed=cfg["seed"],
        # seq-length knob name varies by TRL version; pass both, filtered below
        max_seq_length=cfg["max_seq_length"],
        max_length=cfg["max_seq_length"],
        # eval-strategy knob name varies; pass both, filtered below
        eval_strategy="epoch",
        evaluation_strategy="epoch",
        packing=False,
    )
    return SFTConfig(**_filter_kwargs(SFTConfig, candidate))


class EpochLogCallback:
    """Lazily-defined TrainerCallback that appends per-epoch metrics."""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    args = ap.parse_args()

    cfg = yaml.safe_load(open(args.config))
    os.makedirs(cfg["output_dir"], exist_ok=True)
    yaml.safe_dump(cfg, open(os.path.join(cfg["output_dir"], "training-config.yaml"), "w"))

    # Heavy imports deferred so `--help` / ast-parse / config sanity work
    # without torch/trl present (format-validation host has neither).
    import torch
    from transformers import (
        AutoModelForCausalLM,
        AutoTokenizer,
        BitsAndBytesConfig,
        TrainerCallback,
    )
    from peft import LoraConfig, prepare_model_for_kbit_training
    from trl import SFTConfig, SFTTrainer
    from datasets import load_dataset

    import transformers as _tf
    import trl as _trl
    print(f"transformers={_tf.__version__} trl={_trl.__version__} torch={torch.__version__}")

    bnb = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=getattr(torch, cfg["compute_dtype"]),
        bnb_4bit_use_double_quant=True,
    )

    tokenizer = AutoTokenizer.from_pretrained(cfg["base_model"])
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        cfg["base_model"],
        quantization_config=bnb,
        device_map="auto",
        attn_implementation=cfg.get("attn_impl", "eager"),
    )
    model = prepare_model_for_kbit_training(model)

    lora_cfg = LoraConfig(
        r=cfg["lora_r"],
        lora_alpha=cfg["lora_alpha"],
        lora_dropout=cfg["lora_dropout"],
        target_modules=cfg["lora_target_modules"],
        bias="none",
        task_type="CAUSAL_LM",
    )

    train_ds = load_dataset("json", data_files=cfg["train_file"], split="train")
    val_ds = load_dataset("json", data_files=cfg["val_file"], split="train")

    sft_cfg = build_sft_config(SFTConfig, cfg)

    log_path = os.path.join(cfg["output_dir"], "training-log.json")

    class _EpochLog(TrainerCallback):
        def __init__(self):
            self.rows = []

        def on_epoch_end(self, args, state, control, **kw):
            last = state.log_history[-1] if state.log_history else {}
            self.rows.append({
                "epoch": state.epoch,
                "global_step": state.global_step,
                "loss": last.get("loss"),
                "eval_loss": last.get("eval_loss"),
                "learning_rate": last.get("learning_rate"),
                "samples_seen": state.global_step
                * args.per_device_train_batch_size
                * args.gradient_accumulation_steps,
            })
            json.dump(self.rows, open(log_path, "w"), indent=2)

    trainer_kwargs = dict(
        model=model,
        args=sft_cfg,
        train_dataset=train_ds,
        eval_dataset=val_ds,
        peft_config=lora_cfg,
        callbacks=[_EpochLog()],
    )
    # TRL >=0.9 auto-applies the tokenizer chat template to a "messages"
    # column. Older builds need the tokenizer/processing_class passed
    # explicitly; pass it under whichever kwarg the installed TRL accepts.
    trainer_kwargs = {**trainer_kwargs,
                      **_filter_kwargs(SFTTrainer,
                                       {"processing_class": tokenizer,
                                        "tokenizer": tokenizer})}
    trainer = SFTTrainer(**_filter_kwargs(SFTTrainer, trainer_kwargs))

    trainer.train()

    # Save ONLY the LoRA adapter (+ tokenizer + provenance), never base weights.
    trainer.model.save_pretrained(cfg["output_dir"])
    tokenizer.save_pretrained(cfg["output_dir"])
    print(f"LoRA adapter + tokenizer saved to {cfg['output_dir']}")


if __name__ == "__main__":
    main()
