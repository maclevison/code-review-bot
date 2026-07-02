# Automated PR code review — internal proposal

A drop-in GitHub Actions bot that reviews every pull request with an LLM and
posts an advisory comment. One small workflow file per repo; central config;
provider-agnostic; cheap.

## Problem

- Human review is the bottleneck: PRs wait for a reviewer, and reviewers
  skim large diffs under time pressure.
- Easy-to-miss classes of defects (missing tenant scoping, unhandled edge
  cases, N+1 queries, forgotten validation) slip through.
- Review depth and standards vary by reviewer and by team.

## Solution

An **advisory** reviewer that runs automatically on every PR:

- Comments on findings — bugs/logic, maintainability, performance — grouped
  by severity, citing `file:line`.
- **Never blocks the merge.** It augments human review, it doesn't gate it,
  so there's no adoption friction and no false-positive standoffs.
- Standards live in the repo as `.github/code-review-guidelines.md`, so each
  team encodes its own invariants (e.g. "every query must be tenant-scoped")
  and the bot enforces them consistently.

## How it works

1. On `pull_request` (opened / updated / ready-for-review), a ~10-line
   reusable-workflow call runs.
2. The bot fetches the PR diff, appends the repo's guidelines to a review
   prompt, and makes a single model call.
3. It posts one summary comment on the PR.

No servers to run — it's GitHub Actions. Draft PRs are skipped, superseded
runs are cancelled, and oversized diffs are skipped with a note.

## Cost

- One model call per PR — not an agent loop. Diff-sized input, short output.
- With a cheap code model, that's on the order of **cents per PR** (token
  usage and cost are logged to each run's job summary, so spend is visible).
- Model is a one-line override, so cost/quality is tunable per repo.

## Security & data handling

The decisive question for a company: *where does our code go?*

- The bot speaks the **OpenAI-compatible** protocol, so `base_url` can point
  at whatever Security approves: **Azure OpenAI**, **AWS Bedrock** (via an
  in-VPC gateway), or a **self-hosted** model (vLLM / Ollama / LiteLLM) so
  code never leaves the network.
- On OpenRouter, `require_zero_retention: true` routes only to
  no-data-retention providers.
- **Only the diff is sent** — never the whole repository. The API key is an
  org secret, inherited by repos; nothing is hardcoded.
- Least-privilege token: `contents: read`, `pull-requests: write`.

## Governance

- Central reusable workflow → one place to set the default model, prompt,
  and version. Repos pin a major tag (`@v2`) and get patches automatically.
- Per-repo `code-review-guidelines.md` for team-specific standards.
- Versioned prompt + changelog → auditable behavior over time.

## Rollout plan

1. **Pilot** — one team's repo, `require_zero_retention` on (or self-hosted
   endpoint), 2–4 weeks. Measure signal (useful findings) vs noise.
2. **Tune** — refine the org-default guidelines from pilot feedback; set the
   model per Security/cost.
3. **Expand** — add repos one workflow file at a time; org secret already in
   place.
4. **Optional** — wire a local "apply suggestions" command so authors can
   accept fixes interactively.

## What it is not

- Not a merge gate (advisory by design).
- Not a replacement for human review or for static analysis / CI tests — it
  complements both.
- Not a data exfiltration risk when pointed at an approved/in-VPC endpoint.
