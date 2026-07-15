#!/usr/bin/env bash
#
# Minimal mock for the --llm-cmd transport. Used only by test/selftest.sh.
# Consumes the piped prompt (system prompt + diff) from stdin and answers on
# stdout, so the --llm-cmd path can be exercised deterministically with no real
# agent CLI involved.
#
# $MOCK_CMD_MODE selects the shape of the answer:
#   text (default)  plain-text review, exit 0 — the raw-stdout contract
#   envelope_ok     agent JSON envelope with the review in .response, exit 0
#   envelope_error  agent JSON envelope with status=ERROR, exit 0 (agy does
#                   this: the failure is in the envelope, not the exit code)
#   envelope_bare   valid JSON with no .response/.content/.text field, exit 0
#   fail_stdout     diagnostics on stdout, exit 1 (the bytes worth logging)
set -euo pipefail

cat >/dev/null  # discard the piped prompt

case "${MOCK_CMD_MODE:-text}" in
  envelope_ok)
    cat <<'J'
{"conversation_id":"c-1","status":"SUCCESS","response":"No blocking issues — reviewed via the canned review mock.\n- 🟡 Nit: cosmetic naming suggestion.","error":null,"usage":{"total":42}}
J
    ;;
  envelope_error)
    cat <<'J'
{"conversation_id":"c-1","status":"ERROR","response":null,"error":"Agent execution terminated due to error.","usage":{}}
J
    ;;
  envelope_bare)
    printf '%s\n' '{"conversation_id":"c-1","usage":{}}'
    ;;
  fail_stdout)
    printf '%s\n' '{"status":"ERROR","error":"backend exploded: Error ID be3a6aa3-dead-beef"}'
    exit 1
    ;;
  *)
    cat <<'REVIEW'
No blocking issues — reviewed via the canned review mock.
- 🟡 Nit: cosmetic naming suggestion.
REVIEW
    ;;
esac
