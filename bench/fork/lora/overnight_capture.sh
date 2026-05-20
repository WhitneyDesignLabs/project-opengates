#!/bin/bash
# overnight_capture.sh -- loop persona_01 capture sessions on EvoBot until ~7 AM
# local time. Each session is a normal persona_runner.py run; sessions are
# separated by a short cool-down + /clear bookends inside the runner itself.
#
# Usage (attach to terminal — for smoke-testing the script itself):
#   bash overnight_capture.sh
#
# Usage (detached overnight — what you want):
#   nohup bash overnight_capture.sh > ~/overnight-stdout.log 2>&1 &
#   disown
#
# Stop conditions:
#   - Local hour reaches 07 and is before 17 (the "morning" window). This works
#     for any start time between 17:00 and 06:59. **Override:** set
#     NO_TIME_STOP=1 to disable this check entirely — required for daytime
#     test sessions, because by default the wrapper exits immediately if
#     launched between 07:00 and 17:00 local.
#   - $STOP_FLAG file appears (manual stop: `touch ~/.stop-overnight-capture`).
#   - $MAX_CONSECUTIVE_ERRORS sessions fail in a row (safety net).
#
# Monitor while it runs:
#   cat ~/.overnight-capture.status     # one-line heartbeat
#   tail -f ~/overnight-capture.log     # full per-session log
#   ls ~/wireclaw-corpus/user-side/ | wc -l   # session JSONL count

set -u

# Persona rotation:
#   - Single persona (backward-compatible default): PERSONAS=persona_01_basic
#   - Multiple personas (new): PERSONAS=persona_01_basic,persona_02_power_user,persona_03_ambiguity_tester,persona_04_memory_specialist
# Each session uses the next persona in the list, round-robin.
PERSONAS="${PERSONAS:-persona_01_basic}"
IFS=',' read -ra PERSONA_ARRAY <<< "$PERSONAS"

# Rule-purge bookend (Phase 3.1.2 enhancement).
#   If RULE_PURGE_URL is set, the wrapper curls it at session start to clear
#   any rules accumulated from prior sessions. Endpoint is firmware-specific
#   (the web UI Rules tab "Delete All" button hits some /api/* path; Code
#   investigates in the WireClaw fork source — placeholder for now).
#   When empty (default), the wrapper skips rule purge.
RULE_PURGE_URL="${RULE_PURGE_URL:-http://192.168.1.19/api/rules/delete}"
RULE_PURGE_METHOD="${RULE_PURGE_METHOD:-POST}"
# WireClaw's /api/rules/delete handler REQUIRES a JSON body or it returns 400
# "no body"; {"id":"all"} is the documented delete-all sentinel (web UI
# "Delete All" button sends exactly this). Found in fork src/web_config.cpp:920
# -> handleDeleteRule -> ruleDelete("all"). Override RULE_PURGE_BODY="" to skip.
RULE_PURGE_BODY="${RULE_PURGE_BODY-{\"id\":\"all\"}}"

BOT_USERNAME=wdl_c6_pilot_bot
SESSION_FILE=~/.telethon-evobot.session
OUT_DIR=~/wireclaw-corpus/user-side
STATUS_FILE=~/.overnight-capture.status
STOP_FLAG=~/.stop-overnight-capture
LOG_FILE=~/overnight-capture.log
RUNNER=~/wireclaw-phase31/bench/fork/lora/persona_runner.py
PYTHON=~/phase31-venv/bin/python
MAX_CONSECUTIVE_ERRORS=5
COOLDOWN_OK_S=30      # sleep between successful sessions
COOLDOWN_ERR_S=60     # sleep after a failed session (let the chip recover)

should_stop() {
    if [ -f "$STOP_FLAG" ]; then
        echo "stop-flag-file"
        return 0
    fi
    # Override: NO_TIME_STOP=anything disables the morning-window check
    # entirely. Useful for daytime test/validation sessions. Found 2026-05-16
    # when J4 validation couldn't run during business hours.
    if [ -n "${NO_TIME_STOP:-}" ]; then
        return 1
    fi
    hour=$(date +%H | sed 's/^0//')  # strip leading zero so arithmetic works
    if [ -z "$hour" ]; then hour=0; fi
    if [ "$hour" -ge 7 ] && [ "$hour" -lt 17 ]; then
        echo "morning-window"
        return 0
    fi
    return 1
}

if [ -f ~/.wireclaw-secrets.env ]; then
    set -a
    . ~/.wireclaw-secrets.env
    set +a
fi

if [ ! -x "$PYTHON" ]; then
    echo "ERROR: python venv not found at $PYTHON" >&2
    exit 2
fi
if [ ! -f "$RUNNER" ]; then
    echo "ERROR: persona_runner.py not found at $RUNNER" >&2
    exit 2
fi

mkdir -p "$OUT_DIR"
session_count=0
error_count=0
consecutive_errors=0
start_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "$(date): overnight capture START  personas=$PERSONAS bot=$BOT_USERNAME" | tee -a "$LOG_FILE"
echo "$(date): stop conditions: local hour in [7,17), $STOP_FLAG file, or $MAX_CONSECUTIVE_ERRORS consecutive failures" | tee -a "$LOG_FILE"
if [ -n "$RULE_PURGE_URL" ]; then
    echo "$(date): rule-purge bookend enabled: $RULE_PURGE_METHOD $RULE_PURGE_URL" | tee -a "$LOG_FILE"
else
    echo "$(date): rule-purge bookend DISABLED (RULE_PURGE_URL unset) -- rules may accumulate" | tee -a "$LOG_FILE"
fi

while true; do
    stop_reason=$(should_stop) && break || true

    session_count=$((session_count + 1))
    session_ts=$(date +%FT%H%M%S)
    # Persona rotation: round-robin across PERSONA_ARRAY based on session_count.
    persona_idx=$(( (session_count - 1) % ${#PERSONA_ARRAY[@]} ))
    PERSONA="${PERSONA_ARRAY[$persona_idx]}"
    out_path="$OUT_DIR/${session_ts}_overnight_$(printf '%03d' $session_count)_${PERSONA}.jsonl"

    {
        echo "session=$session_count"
        echo "persona=$PERSONA"
        echo "started_at=$session_ts"
        echo "errors=$error_count"
        echo "consecutive_errors=$consecutive_errors"
        echo "started_run_at=$start_ts"
    } > "$STATUS_FILE"

    echo "$(date): starting session #$session_count persona=$PERSONA -> $out_path" | tee -a "$LOG_FILE"

    # Rule-purge bookend (if configured). Failure here is non-fatal -- log
    # and continue; the session will run with whatever rule state exists.
    if [ -n "$RULE_PURGE_URL" ]; then
        if curl -fsS -X "$RULE_PURGE_METHOD" "$RULE_PURGE_URL" \
                ${RULE_PURGE_BODY:+-H "Content-Type: application/json" --data "$RULE_PURGE_BODY"} \
                >> "$LOG_FILE" 2>&1; then
            echo "$(date): rule-purge OK" | tee -a "$LOG_FILE"
        else
            echo "$(date): rule-purge FAILED (continuing anyway)" | tee -a "$LOG_FILE"
        fi
    fi

    if "$PYTHON" "$RUNNER" \
        --persona "$PERSONA" \
        --bot-username "$BOT_USERNAME" \
        --session-file "$SESSION_FILE" \
        --out "$out_path" >> "$LOG_FILE" 2>&1; then
        consecutive_errors=0
        echo "$(date): session #$session_count OK" | tee -a "$LOG_FILE"
        sleep "$COOLDOWN_OK_S"
    else
        rc=$?
        error_count=$((error_count + 1))
        consecutive_errors=$((consecutive_errors + 1))
        echo "$(date): session #$session_count FAILED rc=$rc (err #$error_count, consec=$consecutive_errors)" | tee -a "$LOG_FILE"
        if [ "$consecutive_errors" -ge "$MAX_CONSECUTIVE_ERRORS" ]; then
            echo "$(date): $MAX_CONSECUTIVE_ERRORS consecutive failures, aborting" | tee -a "$LOG_FILE"
            break
        fi
        sleep "$COOLDOWN_ERR_S"
    fi
done

stop_reason=$(should_stop || echo "max-consecutive-errors")
echo "$(date): overnight capture END  reason=$stop_reason  sessions=$session_count  errors=$error_count" | tee -a "$LOG_FILE"
{
    echo "session_count=$session_count"
    echo "error_count=$error_count"
    echo "ended_at=$(date +%FT%H%M%S)"
    echo "stop_reason=$stop_reason"
} > "$STATUS_FILE.final"
rm -f "$STATUS_FILE"
