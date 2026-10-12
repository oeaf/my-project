#!/bin/bash
# pi-run: delegate a task to Pi with key rotation + model fallback.
#
# Key pool: $HOME/.pi/agent/.keys.env  (chmod 600, NEVER in workspace/chat/memory)
#   Format:
#     KEY_1='sk-...'
#     KEY_2='sk-...'
#     KEY_3='sk-...'
# Order (per user decision 2026-10-09):
#   1. Try DeepSeek-V4-Flash-0731 on each key in order (quota-exhausted keys are skipped).
#   2. Only when DeepSeek failed on ALL keys, try the free Atria-Dawn-Preview once (with KEY_1).
#   3. If that also fails -> report; exit 3 means "all keys exhausted, ask the user for fresh keys".
#
# Usage: pi-run "task prompt" [workdir]
#   Override pool:   PI_KEYS_FILE=/path/to/.keys.env
#   Override models: PI_PRIMARY_MODEL / PI_FALLBACK_MODEL
#
# A "hard failure" = nonzero exit, timeout, or empty output.
# Soft failures (plausible-but-wrong answers) still need a human/judge to spot —
# this script does not try to detect those.
set -u

PROMPT="${1:?usage: pi-run \"task prompt\" [workdir]}"
WORKDIR="${2:-$PWD}"
PRIMARY="${PI_PRIMARY_MODEL:-deepseek-v4-flash-0731}"
PROVIDER="${PI_PROVIDER:-intern}"
FALLBACK="${PI_FALLBACK_MODEL:-Atria-Dawn-Preview}"
KEYS_FILE="${PI_KEYS_FILE:-$HOME/.pi/agent/.keys.env}"

export PATH="$HOME/.pi/agent/bin:$PATH"
export PI_SKIP_VERSION_CHECK=1 PI_TELEMETRY=0

if [ ! -f "$KEYS_FILE" ]; then
  echo "[pi-run] keys file not found: $KEYS_FILE" >&2
  exit 2
fi
chmod 600 "$KEYS_FILE"
# shellcheck disable=SC1090
source "$KEYS_FILE"

KEYS=()
i=1
while :; do
  var="KEY_$i"; val="${!var:-}"
  [ -z "$val" ] && break
  KEYS+=("$val"); i=$((i+1))
done
if [ ${#KEYS[@]} -eq 0 ]; then
  echo "[pi-run] no keys in $KEYS_FILE" >&2
  exit 2
fi

ERRFILE="$(mktemp)"
trap 'rm -f "$ERRFILE"' EXIT

run_model() { # $1 = model name; stdout = model output; return = exit code; stderr -> $ERRFILE
  local model="$1" out rc
  out="$(cd "$WORKDIR" && timeout 280 pi --print --no-session --provider "$PROVIDER" --model "$model" "$PROMPT" < /dev/null 2>"$ERRFILE")"
  rc=$?
  printf '%s' "$out"
  return $rc
}

quota_exhausted() {
  grep -qiE "quota|insufficient|billing|rate.?limit.*exceed|exceed.*rate.?limit" "$ERRFILE"
}

succeeded() { # $1 = output, $2 = rc -> 0 if usable result
  [ "$2" -eq 0 ] && [ -n "$(printf '%s' "$1" | tr -d '[:space:]')" ]
}

# Phase 1: DeepSeek on every key in order
key_n=0
for key in "${KEYS[@]}"; do
  key_n=$((key_n+1))
  export INTERN_API_KEY="$key"
  OUT="$(run_model "$PRIMARY")"; RC=$?
  if succeeded "$OUT" "$RC"; then
    printf '%s\n' "$OUT"
    exit 0
  fi
  if quota_exhausted; then
    echo "[pi-run] key #$key_n quota exhausted -> next key" >&2
  else
    echo "[pi-run] key #$key_n: $PRIMARY failed (exit=$RC) -> next key" >&2
  fi
done

# Phase 2: all DeepSeek attempts failed -> free fallback once (with first key)
echo "[pi-run] all ${#KEYS[@]} key(s) failed on $PRIMARY -> trying free $FALLBACK" >&2
export INTERN_API_KEY="${KEYS[0]}"
OUT="$(run_model "$FALLBACK")"; RC=$?
if succeeded "$OUT" "$RC"; then
  echo "[pi-run] fallback $FALLBACK succeeded" >&2
  printf '%s\n' "$OUT"
  exit 0
fi
if quota_exhausted; then
  echo "[pi-run] KEY_EXHAUSTED: all keys exhausted. Ask the user for fresh keys." >&2
  exit 3
fi
echo "[pi-run] FAILED: $FALLBACK also failed (exit=$RC). All options exhausted." >&2
printf '%s\n' "$OUT"
exit 1
