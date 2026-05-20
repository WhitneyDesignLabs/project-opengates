#!/bin/bash
# Phase 3.2 N6: write manifest.json with accurate counts + full caveats.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, datetime, collections, os
TD='fork/lora/training-data'
cap=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-captured.jsonl',encoding='utf-8')]
syn=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-synthetic.jsonl',encoding='utf-8')]
tr =[json.loads(l) for l in open(f'{TD}/wireclaw-v1-train.jsonl',encoding='utf-8')]
va =[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.jsonl',encoding='utf-8')]
capm=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-captured.meta.jsonl',encoding='utf-8')]
pers=collections.Counter(m['persona'] for m in capm)
chip=collections.Counter(m['chip'] for m in capm)
n=len(cap)
sl_actual=len(open(f'{TD}/constitution/SOUL-LOCAL.md','rb').read())
manifest={
 "version":"wireclaw-v1",
 "base_model":"meta-llama/Llama-3.1-8B-Instruct",
 "source":"3.1.3 corpus (V2 Haiku labels) + synthetic constitutional examples",
 "constitution_source":{
   "training_system_prompt":f"SOUL-LOCAL.md (v0.2.0 distillation, {sl_actual} bytes on disk / 5635-byte system message after stripping 3 leading comment lines, all 26 articles)",
   "runtime_system_prompt_for_chip":"SOUL-CHIP.md (3069 bytes, fits 4095-byte chip limit)",
   "canonical_source":"https://www.clawhub.ai/souls/opengates-constitution"},
 "build_date":datetime.datetime.now().astimezone().isoformat(),
 "total_examples":len(cap)+len(syn),
 "captured_examples":len(cap),
 "synthetic_examples":len(syn),
 "train_examples":len(tr),
 "val_examples":len(va),
 "captured_filter_rules":[
   "haiku_label == clean",
   "non-empty response (no silent-execution turns)",
   "not in c6-02/c6-03 wedge window (last 60 min of capture)"],
 "captured_drop_counts":{"non_clean_label":2605,"empty_response":248,"wedge_window":67},
 "synthetic_articles_covered":["5","6","8","9","10","11","17","21","22","23","24"],
 "persona_distribution":{k:f"{v} ({100*v/n:.1f}%)" for k,v in pers.most_common()},
 "chip_distribution":{k:f"{v} ({100*v/n:.1f}%)" for k,v in chip.most_common()},
 "methodology_caveats":[
   "wireclaw-agent:v1 Modelfile SYSTEM had drifted from canonical SOUL.md. v1.1 corrects this — training system prompt is SOUL-LOCAL.md verbatim, runtime system prompt is SOUL-CHIP.md.",
   "Phase 3.2 step 2 used LLM-vs-LLM calibration (Cowork labels), not human labels. Per-class agreement: clean 87%, pp 90%, fab 80%, contradictory 4.2% (dropped class).",
   "Synthetic constitutional examples generated via Haiku API; not human-curated. Spot-checked on output but not exhaustively reviewed.",
   "FLAG (Code): 72 synthetic tool-call invocations across 54/90 synthetic examples use tool names NOT in the WireClaw toolset (37 distinct invented names, e.g. thermostat_set, automation_rule_create). The N3.5 generator prompt did not enumerate the real tool list. Captured examples = 0 such violations. Cowork decision needed: regenerate N3.5 with the real toolset, or strip tool_calls from synthetic examples before Phase 3.3 (the constitutional value is in the prose, mostly non-tool).",
   "FLAG (Code): Llama 3.1 tool-call rendering could NOT be validated locally — meta-llama/Llama-3.1-8B-Instruct is gated/unavailable; the NousResearch mirror's chat_template has NO tool-call support (drops the tool_calls field and emits a stray empty assistant header). Plain system/user/assistant text + special tokens render correctly. Phase 3.3 must validate tool-call rendering with the real (tool-aware) Llama 3.1 template.",
   "FLAG (Code): directive cited SOUL-LOCAL.md as 10155 bytes; actual file is %d bytes (5635-byte system-message string after stripping the 3 leading comment lines). Used actual content verbatim per directive (no modification)." % sl_actual,
 ],
}
open(f'{TD}/manifest.json','w',encoding='utf-8').write(json.dumps(manifest,indent=2))
print(json.dumps(manifest,indent=2))
EOF
