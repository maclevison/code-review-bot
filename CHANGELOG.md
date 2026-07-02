# Changelog

## v2.3.0 — 2026-07-02

- New `require_zero_retention` input (OpenRouter): routes only to providers
  that do not retain data (`provider.data_collection=deny`). Default
  `false` — no change to existing behavior.
- Observability: token usage (and cost when reported) is written to the
  GitHub Actions job summary on every run.
- README: added a "Data handling & providers" section (Azure OpenAI,
  Bedrock, self-hosted vLLM/Ollama/LiteLLM via `base_url`).

All additions are backward-compatible; consumers on `@v2` need no changes.

## v2.2.0 — 2026-07-02

- Default `model` changed from `deepseek/deepseek-v4-flash-20260423` to
  `moonshotai/kimi-k2.7-code-20260612` (code-specialized). Override via the
  `model` input.

## v2.1.0 — 2026-07-02

- Repo-specific review guidelines: the bot now reads
  `.github/code-review-guidelines.md` (configurable via the new
  `guidelines_path` input) from the reviewed repo at the PR head commit and
  appends it to the built-in prompt. Absent file → defaults unchanged.
- Added `templates/code-review-guidelines.md` as a starting point.

## v2.0.0 — 2026-07-02

**Breaking:** engine switched from the Claude Code Action to a provider-
agnostic single-shot review via OpenRouter (much cheaper per PR).

- Reusable workflow renamed `claude-review.yml` → `review.yml`; consumers
  pin `@v2` and call `.../review.yml@v2`.
- Secret renamed `ANTHROPIC_API_KEY` → `OPENROUTER_API_KEY`.
- New/changed inputs: `model` now an OpenRouter model id
  (default `deepseek/deepseek-v4-flash-20260423`), new `base_url`
  (default `https://openrouter.ai/api/v1`).
- One API call per PR posts a single advisory summary comment (no more
  agentic multi-turn run, no inline comments). Draft skip, superseded-run
  cancellation, and the `max_diff_lines` guard are retained.
- Provider errors / empty responses post a short "review unavailable"
  comment and exit successfully instead of failing the check.

## v1.1.0 — 2026-07-02

- Default `model` changed from `claude-opus-4-8` to `claude-sonnet-5`
  (lower cost, strong review quality). Override via the `model` input.
- Enable `track_progress: true` on the action: PRs now show a live
  "in progress" tracking comment while the review runs.

## v1.0.0 — 2026-07-02

Initial release.

- Reusable workflow `claude-review.yml`: advisory Claude code review on
  pull requests via `anthropics/claude-code-action@v1`.
- Inputs: `model` (default `claude-opus-4-8`), `extra_instructions`,
  `max_diff_lines` (default 5000).
- Skips draft PRs, cancels superseded runs, skips oversized diffs with an
  explanatory comment.
- Consumer template and adoption guide.
