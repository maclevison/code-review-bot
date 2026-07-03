<div align="center">

# 🤖 code-review-bot

### AI code review on every pull request — for cents, in one workflow file.

An advisory reviewer that reads your diff, comments on the bugs, and gets out of the way.
It **never blocks a merge**. It just makes every PR a little safer.

**Drop-in · Provider-agnostic · No servers · Yours in 5 minutes**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[Get started](#-get-started-in-5-minutes) · [Why teams adopt it](#why-teams-adopt-it) · [Features](#everything-you-get) · [Security](#your-code-your-endpoint) · [Config](#configuration-reference)

</div>

```yaml
# .github/workflows/code-review.yml — that's the whole integration
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
jobs:
  review:
    permissions:
      contents: read
      pull-requests: write
    uses: OWNER/code-review-bot/.github/workflows/review.yml@v2
    secrets: inherit
```

---

## The problem you already have

Human review is the bottleneck. PRs sit waiting for a reviewer. When someone
finally looks, they skim a 900-line diff under time pressure — and the boring
defects slip through:

- missing tenant scoping on a query
- an unhandled edge case
- an N+1 that ships to prod
- validation that was quietly forgotten

Review depth swings by reviewer, by team, by how tired everyone is on Friday.

## The fix: a tireless first-pass reviewer

`code-review-bot` reads **every** non-draft PR the moment it opens, and posts
**one** clear comment grouped by severity, citing `file:line`. Bugs & logic,
maintainability, performance. Your reviewers walk into a diff that's already
been read once.

It's **advisory by design** — it comments, humans decide. No merge gate, no
false-positive standoffs, no adoption friction. That's the whole trick: because
it can't block you, nobody fights it, so everybody keeps it on.

> **Don't** add the review job to branch-protection required checks. Advisory means advisory.

---

## Why teams adopt it

| | |
|---|---|
| 💸 **Cents per PR** | One model call per PR — not an agent loop. Diff in, short review out. Token usage & cost land in the job summary, so spend is never a mystery. |
| 🔌 **One file to adopt** | Copy a ~10-line workflow into a repo. Next PR gets reviewed. No app to install, no server to run, no webhook to babysit. |
| 🏢 **Central config, org-wide** | One reusable workflow sets the default model, prompt, and version. Repos pin `@v2` and get patches automatically. |
| 🔒 **Your code, your endpoint** | Speaks the OpenAI protocol — point it at OpenRouter, Azure, Bedrock, or a self-hosted model so code never leaves your network. |
| 📏 **Your standards, enforced** | Drop a guidelines file in the repo; the bot enforces your invariants ("every query must be tenant-scoped") consistently, on every PR. |
| 🛟 **Fails safe, always** | Bad key, no credit, empty reply, oversized diff — it posts a short note and exits green. It never breaks your CI. |

---

## Everything you get

- **Findings tagged by severity** — every finding is prefixed 🔴 Important / 🟡 Nit / 🟣 Pre-existing and cites `file:line`, opening with a one-line tally. Bugs/logic, quality, performance. Inline nits are capped so the review stays actionable.
- **Named anti-pattern hunting** — beyond generic "quality", the prompt names concrete smells to catch: parameter bloat, leaky abstractions, stringly-typed code, TOCTOU races, no-op updates, over-broad queries, redundant state, and reuse-before-write.
- **Diff-aware triage** — before reviewing, the bot classifies the diff (size bucket; touches DB migrations / auth-sensitive paths / config / no tests) and feeds those signals to the model so it weights the review where risk lives.
- **Conditional security deep-dive** — when the diff touches auth- or DB-sensitive paths, an extra checklist (injection, IDOR/authz, secrets/PII, XSS, unsafe input) is added to the prompt — and **only** then, so ordinary PRs pay nothing.
- **Repo-specific guidelines** — a `.github/code-review-guidelines.md` refines the built-in prompt with your team's rules, focus areas, severity scale, and format.
- **`REVIEW.md` override** — a repo-root `REVIEW.md` (Claude Code Review convention) is injected verbatim as **highest-priority** review-only instructions that override the defaults, the guidelines file, and `extra_instructions`. Loaded from the **target branch**, so a PR can't inject rules to steer its own review.
- **Opt-in severity gating** — the review stays advisory, but exposes `reviewed` / `important` / `nit` / `pre_existing` as **workflow outputs** so a downstream job can choose to block. A human-readable tally also lands in the job summary (see [§4](#4-optional-opt-in-to-severity-gating)).
- **Built-in cost controls** — drafts skipped, superseded runs cancelled on new pushes, diffs over `max_diff_lines` (default 5000) skipped with an explanatory comment.
- **Per-PR observability** — a token-usage table (and cost, when the provider reports it) written to the GitHub Actions **job summary**.
- **Any model, one line** — swap `moonshotai/kimi-k2.7-code-20260612` for any OpenRouter id, or any OpenAI-compatible endpoint, without touching the workflow.
- **Least-privilege** — `contents: read`, `pull-requests: write`. Only the diff is sent, never the whole repo.
- **Tunable reviewer voice** — set the comment heading (`bot_name`), toggle the model footer, cap `max_tokens` and `reasoning_effort` for thinking models.

---

## 🚀 Get started in 5 minutes

### 1. One-time setup (per org or account)

Get an OpenRouter API key at <https://openrouter.ai/keys> and add credit. Then
store it as a secret named `OPENROUTER_API_KEY`:

```bash
# Organization (repos inherit it via `secrets: inherit`)
gh secret set OPENROUTER_API_KEY --org YOUR_ORG --visibility all

# …or per personal repo
gh secret set OPENROUTER_API_KEY --repo YOUR_USER/YOUR_REPO
```

Make this repo callable by consumers:
- **Public repo:** works as-is.
- **Private/internal in an org:** Settings → Actions → General → Access →
  "Accessible from repositories in the organization".

### 2. Adopt in any repo

Copy `templates/consumer-workflow.yml` to `.github/workflows/code-review.yml`
in the target repo and replace `OWNER` with the user/org hosting this repo.
That's it — the next non-draft PR gets reviewed.

> The host repo must be named `code-review-bot`, or edit the `code-review-bot`
> path segment in the consumer template to match your repo name.

### 3. (Optional) Teach it your standards

Drop `.github/code-review-guidelines.md` in the reviewed repo to define what to
focus on, what to ignore, the severity scale, and the response format. The bot
reads it at the PR's head commit and appends it to its prompt — the baseline
still applies, your file refines it. Copy `templates/code-review-guidelines.md`
to start. No file → the bot uses its defaults.

For **hard rules you always want honored**, drop a `REVIEW.md` at the repo root
instead. Following the Claude Code Review convention, it's injected verbatim as
highest-priority, review-only instructions that override the defaults, the
guidelines file, **and** `extra_instructions` when they conflict. `REVIEW.md` is
loaded from the **target branch** (not the PR head), so only merged rules take
effect — a PR can't add a `REVIEW.md` to steer its own review. The guidelines
file still loads at the PR head; either, both, or neither may exist.

### 4. (Optional) Opt in to severity gating

The bot stays **advisory** — it never fails your CI. But it exposes the severity
counts as **workflow outputs** so *you* can choose to gate in a downstream job.
It also writes a human-readable tally to the job summary:

```
Findings: 🔴 2 · 🟡 1 · 🟣 3
```

Because this is a reusable (`workflow_call`) workflow, a per-job
`$GITHUB_STEP_SUMMARY` can't be read across jobs — so gate on the workflow
**outputs** instead. Add a second job that `needs` the review:

```yaml
jobs:
  review:
    uses: OWNER/code-review-bot/.github/workflows/review.yml@v2
    secrets: inherit
  gate:
    needs: review
    runs-on: ubuntu-latest
    steps:
      - run: |
          # `reviewed` is 'true' only when a review actually completed. Fail
          # closed if it didn't run, then block on important findings.
          if [ "${{ needs.review.outputs.reviewed }}" != "true" ]; then
            echo "::error::code review did not complete"; exit 1
          fi
          important="${{ needs.review.outputs.important }}"
          [ "${important:-0}" -eq 0 ] || { echo "::error::${important} important finding(s)"; exit 1; }
```

Available outputs: `reviewed`, `important`, `nit`, `pre_existing`. The
`important`/`pre_existing` counts are exact; `nit` counts only the inline-listed
nits (the prompt caps them), so it may undercount on large reviews. Gating is
entirely your call; the review job itself always exits green.

---

## How it works

On `pull_request` (opened, synchronize, reopened, ready_for_review), the
consumer workflow calls the reusable workflow here, which:

1. Skips draft PRs and cancels superseded runs for the same PR.
2. Fetches the PR diff via the GitHub API (no checkout needed). If the diff
   exceeds `max_diff_lines`, posts a skip comment and exits successfully.
3. Triages the diff (size, DB/auth/config/test signals) and, for
   security-sensitive changes, adds a focused security checklist to the prompt.
   Loads your `guidelines_path` file and repo-root `REVIEW.md` if present.
4. Sends the diff in a single request to the configured model with the embedded
   review prompt, then posts the response as one advisory summary comment and
   exposes the severity counts as workflow outputs.

If the provider errors (bad key, no credit) or returns an empty response, the
job posts a short "review unavailable" comment and exits successfully — it
never fails the check or blocks the PR (and `reviewed` stays unset, so a gate
can fail closed).

---

## Your code, your endpoint

The decisive question for any company: *where does our code go?*

Because the bot speaks the **OpenAI-compatible** protocol, `base_url` can point
at whatever Security approves:

- **OpenRouter (default)** — set `require_zero_retention: true` to route only to
  providers that don't retain data.
- **Azure OpenAI** — `base_url` to your Azure endpoint; the deployment name is the `model`.
- **AWS Bedrock** — via an OpenAI-compatible gateway (LiteLLM / Bedrock Access Gateway) in your own VPC.
- **Self-hosted** — vLLM, Ollama, or LiteLLM inside your network, so code never leaves your infrastructure.

The `OPENROUTER_API_KEY` secret is just the bearer token for `base_url` — name
aside, it carries whatever provider's key you configure. **Only the diff is
sent; the bot never uploads the full repository.**

---

## Configuration reference

### Inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `model` | string | `moonshotai/kimi-k2.7-code-20260612` | Any OpenRouter model id (e.g. `deepseek/deepseek-v4-flash-20260423`, `z-ai/glm-5.2`, `google/gemini-3.5-flash`) |
| `base_url` | string | `https://openrouter.ai/api/v1` | OpenAI-compatible base URL; point it at another provider if you prefer |
| `extra_instructions` | string | `""` | Extra review instructions appended to the system prompt (e.g. project-specific rules) |
| `max_diff_lines` | number | `5000` | Skip the review when the PR diff exceeds this many lines |
| `guidelines_path` | string | `.github/code-review-guidelines.md` | Path in the reviewed repo to a Markdown file of repo-specific review norms; appended to the prompt when present |
| `require_zero_retention` | boolean | `false` | OpenRouter only: route only to providers that do not retain data (`provider.data_collection=deny`). Leave `false` for non-OpenRouter `base_url`. |
| `bot_name` | string | `🤖 Kimo Reviewer` | Heading at the top of the review comment (Markdown; include your own emoji if you want one) |
| `show_model_footer` | boolean | `false` | Show the `_Model: … advisory_` line under the heading |
| `max_tokens` | number | `8000` | Max completion tokens for the reply. Reasoning models spend tokens thinking; too low a cap truncates the review (`finish_reason=length` → empty). |
| `reasoning_effort` | string | `low` | OpenRouter reasoning effort for thinking models (`low`/`medium`/`high`). `low` stops a reasoning model from spending its whole token budget thinking and leaving the review empty. Set `''` to omit. |

### Secrets

| Secret | Required | Description |
|---|---|---|
| `OPENROUTER_API_KEY` | yes | OpenRouter API key; provided via `secrets: inherit` from the org/repo secret |

### Versioning

Consumers pin `@v2`. Semantic tags (`v2.0.0`, `v2.1.0`, …) are cut per release
and the floating `v2` tag moves to the latest compatible release. Breaking
changes ship as a new major tag; existing consumers are unaffected until they
opt in. (`v1` was the Claude-based engine.)

---

## What it is *not*

- **Not a merge gate.** Advisory by design — keep it out of required checks.
- **Not a replacement** for human review, static analysis, or CI tests — it complements all three.
- **Not a data-exfiltration risk** when pointed at an approved / in-VPC endpoint.

---

## License

[MIT](LICENSE) © 2026 Mac Silva.

---

<div align="center">

**Every PR, read once before a human even looks. For cents.**

[Get started](#-get-started-in-5-minutes) · [See the pitch](docs/PITCH.md) · [Changelog](CHANGELOG.md)

</div>
