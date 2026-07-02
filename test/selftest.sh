#!/usr/bin/env bash
#
# Deterministic self-test for the review pipeline. It mirrors the core
# request/parse/guard logic of .github/workflows/review.yml against a mock
# OpenRouter server (test/mock_openrouter.py), so no real API call, token
# cost, or network is involved.
#
# NOTE: this is Option A (inline test). The core flow below is a COPY of the
# logic in review.yml — keep the two in sync when you change either.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PORT=8137
BASE_URL="http://127.0.0.1:${PORT}"
MODEL="mock/model"
SYSTEM="You are an automated code reviewer."
DIFF="$(cat "$HERE/fixtures/sample.diff")"
MOCK_PID=""

fail() { echo "FAIL: $1" >&2; exit 1; }

start_mock() {
  MOCK_MODE="$1" PORT="$PORT" python3 "$HERE/mock_openrouter.py" &
  MOCK_PID=$!
  for _ in $(seq 1 50); do
    if curl -s -o /dev/null "$BASE_URL"; then break; fi
    sleep 0.1
  done
}

stop_mock() {
  [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null || true
  wait "$MOCK_PID" 2>/dev/null || true
  MOCK_PID=""
}
trap stop_mock EXIT

# Mirror of review.yml: build payload -> call -> parse -> guard.
# Prints the review text on success, or a __TOKEN__ marking the graceful path
# that review.yml would take (post "unavailable" comment, exit 0).
run_core() {
  local payload resp review
  payload=$(jq -n \
    --arg model "$MODEL" \
    --arg system "$SYSTEM" \
    --arg user "$DIFF" \
    --argjson zdr false \
    --argjson mt 8000 \
    '{model: $model, max_tokens: $mt, messages: [
       {role: "system", content: $system},
       {role: "user", content: ("Review this pull request diff:\n\n" + $user)}
     ]}
     + (if $zdr then {provider: {data_collection: "deny"}} else {} end)')

  resp=$(curl -sS --fail-with-body -X POST "${BASE_URL}/chat/completions" \
    -H "Authorization: Bearer test" \
    -H "Content-Type: application/json" \
    -d "$payload") || { echo "__CURL_FAIL__"; return 0; }

  review=$(printf '%s' "$resp" | jq -r '.choices[0].message.content // empty') || {
    echo "__MALFORMED__"; return 0;
  }
  if [ -z "$review" ]; then echo "__EMPTY__"; return 0; fi
  printf '%s' "$review"
}

# Test 1 — happy path: valid response is parsed and carries the canned review.
start_mock ok
out=$(run_core)
stop_mock
printf '%s' "$out" | grep -q "discount.js:2" \
  || fail "happy path: expected review to reference discount.js:2, got: $out"
echo "PASS  happy path (request built, response parsed, review extracted)"

# Test 2 — non-JSON 200 body must degrade gracefully (not crash the step).
start_mock html
out=$(run_core)
stop_mock
[ "$out" = "__MALFORMED__" ] || fail "malformed: expected __MALFORMED__, got: $out"
echo "PASS  malformed 200 body degrades gracefully"

# Test 3 — empty content must degrade gracefully.
start_mock empty
out=$(run_core)
stop_mock
[ "$out" = "__EMPTY__" ] || fail "empty: expected __EMPTY__, got: $out"
echo "PASS  empty response degrades gracefully"

echo "ALL SELFTESTS PASSED"
