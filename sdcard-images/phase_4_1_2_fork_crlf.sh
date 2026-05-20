#!/bin/bash
# Phase 4.1.2 follow-up: clean the CRLF churn in WireClaw-fork and pin
# line endings going forward via .gitattributes. Scott approved L1.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw-fork
echo "== before =="
git diff --stat
echo
echo "== discarding CRLF-only working-tree changes =="
git checkout -- \
  data/system_prompt.txt \
  include/llm_client.h \
  src/llm_client.cpp \
  src/main.cpp \
  src/tools.cpp
echo
echo "== writing .gitattributes =="
cat > .gitattributes <<'EOF'
# Pin all text files to LF in the index so Windows editors that emit CRLF
# do not produce phantom whole-file diffs (Phase 4.1.2 follow-up).
* text=auto eol=lf

# Explicitly text — no autodetection ambiguity:
*.cpp     text eol=lf
*.h       text eol=lf
*.c       text eol=lf
*.py      text eol=lf
*.sh      text eol=lf
*.md      text eol=lf
*.txt     text eol=lf
*.yaml    text eol=lf
*.yml     text eol=lf
*.json    text eol=lf

# Binaries:
*.png     binary
*.jpg     binary
*.bin     binary
*.gguf    binary
*.safetensors binary
EOF

echo
echo "== post-checkout diff status =="
git diff --stat
echo
echo "== staging .gitattributes + committing =="
git add .gitattributes
git -c user.name="Scott Whitney" \
    -c user.email="scott@whitneydesignlabs.com" \
    -c commit.gpgsign=false \
    commit -m "$(cat <<EOF
gitattributes: pin text files to LF eol; clear Windows-CRLF churn

A Windows editor re-saved 5 source files with CRLF line endings, which
git interpreted as a whole-file diff against the committed LF versions
(4023 insertions == 4023 deletions, byte-identical content). Discard
the CRLF working-tree noise via \`git checkout --\` and add a
.gitattributes pinning all text formats to LF so this does not recur.

Files affected by the discard:
- data/system_prompt.txt
- include/llm_client.h
- src/llm_client.cpp
- src/main.cpp
- src/tools.cpp

No source-of-truth content changed. bf80fa9 remains tip of wdl-v1.
EOF
)"
echo
echo "== result =="
git log --oneline -3
git status
