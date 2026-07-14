#!/usr/bin/env bash
#
# Minimal mock for the --llm-cmd transport. Used only by test/selftest.sh.
# Consumes the piped prompt (system prompt + diff) from stdin and prints a
# canned review to stdout, so the --llm-cmd path can be exercised
# deterministically with no real agent CLI involved.
set -euo pipefail

cat >/dev/null  # discard the piped prompt

cat <<'REVIEW'
No blocking issues — reviewed via the canned review mock.
- 🟡 Nit: cosmetic naming suggestion.
REVIEW
