# Changelog

## v1.0.0 — 2026-07-02

Initial release.

- Reusable workflow `claude-review.yml`: advisory Claude code review on
  pull requests via `anthropics/claude-code-action@v1`.
- Inputs: `model` (default `claude-opus-4-8`), `extra_instructions`,
  `max_diff_lines` (default 5000).
- Skips draft PRs, cancels superseded runs, skips oversized diffs with an
  explanatory comment.
- Consumer template and adoption guide.
