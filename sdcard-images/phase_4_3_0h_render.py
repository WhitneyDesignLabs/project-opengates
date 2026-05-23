#!/usr/bin/env python3
"""
Phase 4.3.0.H render — produces rendered Modelfiles for both v1.3.1 (control)
and v1.3.1-grounded (treatment) into /tmp, then prints a unified diff.

Mirrors the rendering logic of sdcard-images/phase_4_2_1g_build.sh deploy step,
but for both arms of the upcoming A/B. No network calls; no scp; no ollama create.
Local-only — pure template rendering + diff. The diff is the artifact H.2 surfaces
for Cowork+Scott review at the hard gate before H.3.

Usage:
    python3 phase_4_3_0h_render.py
"""
import datetime
import difflib
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
TRAINING = ROOT / "bench" / "fork" / "lora" / "training"
SOUL_CHIP = ROOT / "bench" / "fork" / "lora" / "training-data" / "constitution" / "SOUL-CHIP.md"

TPL_V1_3   = TRAINING / "wireclaw-agent-v1.3.Modelfile.template"
TPL_GROUND = TRAINING / "wireclaw-agent-v1.3.1-grounded.Modelfile.template"

OUT_V1_3_1 = pathlib.Path("/tmp/wireclaw-agent-v1.3.1.Modelfile")
OUT_GROUND = pathlib.Path("/tmp/wireclaw-agent-v1.3.1-grounded.Modelfile")

# fixed build date so the diff is reproducible — actual deploy can re-render with utcnow().
BUILD_DATE = "2026-05-22T00:00:00Z"
ADAPTER_PATH = "/home/azza/wireclaw-v1.3.1.gguf"  # same artifact for both arms

soul_chip = SOUL_CHIP.read_text(encoding="utf-8").strip()


def render(template_path: pathlib.Path, banner_rewrites: list[tuple[str, str]] = None) -> str:
    out = template_path.read_text(encoding="utf-8")
    out = out.replace("<BUILD_DATE>", BUILD_DATE)
    out = out.replace("<PATH_TO_V1.3_LORA_GGUF>", ADAPTER_PATH)
    out = out.replace("<SOUL_CHIP_INLINE>", soul_chip)
    for old, new in banner_rewrites or []:
        out = out.replace(old, new)
    return out


# Arm A — v1.3.1 control. Mirror phase_4_2_1g_build.sh deploy banner rewrites exactly.
v1_3_1_text = render(
    TPL_V1_3,
    banner_rewrites=[
        ("# wireclaw-agent v1.3 ", "# wireclaw-agent v1.3.1 "),
        (
            "v1.3 LoRA (targeted constitutional repair)",
            "v1.3.1 LoRA (regression patch on v1.3 — harm article specificity + truth/uncertainty hedge-engage)",
        ),
    ],
)

# Arm B — v1.3.1-grounded treatment. The standalone template already has the
# v1.3.1-grounded banner baked in; only placeholder substitution needed.
ground_text = render(TPL_GROUND)

OUT_V1_3_1.write_text(v1_3_1_text, encoding="utf-8")
OUT_GROUND.write_text(ground_text, encoding="utf-8")

print(f"wrote {OUT_V1_3_1} ({len(v1_3_1_text)} bytes)")
print(f"wrote {OUT_GROUND} ({len(ground_text)} bytes)")
print()
print("=== unified diff: v1.3.1 (control) vs v1.3.1-grounded (treatment) ===")
diff = difflib.unified_diff(
    v1_3_1_text.splitlines(keepends=True),
    ground_text.splitlines(keepends=True),
    fromfile=str(OUT_V1_3_1),
    tofile=str(OUT_GROUND),
    n=3,
)
for line in diff:
    print(line, end="")
