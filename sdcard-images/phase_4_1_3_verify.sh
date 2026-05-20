#!/bin/bash
# Phase 4.1.3 Step 9: verify canonical SOUL URL is present on every
# public surface.
set -u
URL='clawhub.ai/souls/opengates-constitution'
check() {
  local label="$1" src="$2"
  local body
  body=$(curl -sL --max-time 20 "$src")
  local code=$(curl -sLI --max-time 20 -o /dev/null -w '%{http_code}' "$src")
  local hits=$(echo "$body" | grep -c "$URL" || true)
  printf "%-50s HTTP %s   '%s' hits: %d\n" "$label" "$code" "$URL" "$hits"
}

check "1) canonical URL itself" \
  'https://clawhub.ai/souls/opengates-constitution'
check "2) workspace README" \
  'https://raw.githubusercontent.com/WhitneyDesignLabs/project-opengates/main/README.md'
check "3) workspace SOUL.md" \
  'https://raw.githubusercontent.com/WhitneyDesignLabs/project-opengates/main/SOUL.md'
check "4) workspace CLAUDE.md" \
  'https://raw.githubusercontent.com/WhitneyDesignLabs/project-opengates/main/CLAUDE.md'
check "5) workspace PROJECT_STATUS.md" \
  'https://raw.githubusercontent.com/WhitneyDesignLabs/project-opengates/main/PROJECT_STATUS.md'
check "6) HF model card" \
  'https://huggingface.co/WhitneyDesignLabs/wireclaw-agent-v1.1-lora/raw/main/README.md'
check "7) fork README-WhitneyDesignLabs (branch)" \
  'https://raw.githubusercontent.com/WhitneyDesignLabs/WireClaw/docs-canonical-soul-url/README-WhitneyDesignLabs.md'
check "8) fork README-WhitneyDesignLabs (wdl-v1)" \
  'https://raw.githubusercontent.com/WhitneyDesignLabs/WireClaw/wdl-v1/README-WhitneyDesignLabs.md'

echo
echo "(Note: surface 8 is expected to show 0 hits unless Scott merges"
echo " docs-canonical-soul-url into wdl-v1.)"
