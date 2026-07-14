#!/usr/bin/env bash
#
# Minimal `gh` stub for test/selftest.sh. Copied to a temp dir as `gh` and put
# first on PATH, so --pr/--comment mode can be exercised with no GitHub, token,
# or network involved.
#
# Only the subcommands panoptes actually calls in --pr mode are stubbed:
#   pr diff    -> the fixture diff ($MOCK_GH_FIXTURE)
#   pr view    -> exit 1, so the guidelines/REVIEW.md API lookups are skipped
#   pr comment -> captures the body to $MOCK_GH_COMMENT_OUT and, like the real
#                 gh, echoes the new comment's URL on stdout
#   api/repo   -> exit 1 (nothing to serve)
set -euo pipefail

case "${1:-}" in
  pr)
    case "${2:-}" in
      diff)
        cat "$MOCK_GH_FIXTURE"
        ;;
      comment)
        body_file=""
        while [ $# -gt 0 ]; do
          case "$1" in
            --body-file) body_file="${2:-}"; shift 2 ;;
            *) shift ;;
          esac
        done
        if [ -n "${MOCK_GH_COMMENT_OUT:-}" ] && [ -n "$body_file" ]; then
          cp "$body_file" "$MOCK_GH_COMMENT_OUT"
        fi
        # The real `gh pr comment` prints the created comment's URL on stdout.
        # Reproducing that here is the point of this stub: it is what must NOT
        # end up mixed into panoptes' --format json output.
        printf '%s\n' "https://github.com/mock/repo/pull/1#issuecomment-1234567890"
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  *)
    exit 1
    ;;
esac
