#!/bin/bash
# Phase 4.3.0.H.4 smoke — send a single /api/chat to azza's Ollama daemon
# targeting wireclaw-agent:v1.3.1-grounded. Multi-turn shape that exercises
# the wrap-up branch (user → assistant tool_call → tool result → expect wrap-up),
# which is exactly the shape that produced 82.9% template-token leak in
# 4.3.0.F's broken mid-conversation-injection delivery channel.
#
# Pass criteria:
#   (i)  response is well-formed JSON
#   (ii) message.content has zero Llama-3.1 chat-template tokens
#        (<|start_header_id|>, <|end_header_id|>, <|eot_id|>, <|begin_of_text|>)
#
# Failure → STOP per H.3 directive.

set -u

ssh -o BatchMode=yes azza@azza.tail63f48.ts.net 'curl -sS http://localhost:11434/api/chat -d @- <<JSON
{
  "model": "wireclaw-agent:v1.3.1-grounded",
  "stream": false,
  "options": {"temperature": 0.5},
  "messages": [
    {"role": "user", "content": "Same as before, please."},
    {"role": "assistant", "content": "", "tool_calls": [{"function": {"name": "file_read", "arguments": {"path": "/memory.txt"}}}]},
    {"role": "tool", "content": "favorite color: green"}
  ]
}
JSON'
