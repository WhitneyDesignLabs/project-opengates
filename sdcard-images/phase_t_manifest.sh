#!/bin/bash
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json
p="fork/lora/training-data/manifest.json"; m=json.load(open(p))
m["methodology_caveats"]=[c for c in m["methodology_caveats"]
                          if not c.startswith("OPEN (Phase 3.3.1 N3)")]
m["methodology_caveats"].append(
 "BLOCKER (Phase 3.3.1 N3, validated with real meta-llama tokenizer): "
 "single-tool & no-tool turns render correctly via the Llama 3.1 chat "
 "template; MULTI tool_call turns HARD-FAIL (TemplateError: only single "
 "tool-calls supported). Affects 41/769 examples (37 train/4 val; 16 "
 "captured=2.3%, 25 synthetic=28%). Phase 3.3.2 must resolve before "
 "training. Cowork decision pending — NOT auto-fixed.")
m["tool_render_validation"]={
 "tokenizer":"meta-llama/Llama-3.1-8B-Instruct (authed)",
 "single_tool":"OK","no_tool":"OK",
 "multi_tool":"TemplateError - blocks 41/769",
 "rendered_tool_shape":'{"name": <tool>, "parameters": "<json-string of args>"}'}
json.dump(m,open(p,"w"),indent=2)
print("manifest updated; caveats:",len(m["methodology_caveats"]),
      "| tool_render_validation added")
EOF
