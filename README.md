<div align="center">

# 🤖 code-review-bot

### AI code review on every pull request — for cents, in one workflow file.

An advisory reviewer that reads your diff, comments on the bugs, and gets out of the way.
It **never blocks a merge**. It just makes every PR a little safer.

**Drop-in · Provider-agnostic · No servers · Yours in 5 minutes**

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

[Get started](#-get-started-in-5-minutes) · [Why teams adopt it](#why-teams-adopt-it) · [Features](#everything-you-get) · [Security](#your-code-your-endpoint) · [Config](#configuration-reference)

</div>

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

- **Severity-grouped findings** citing `file:line` — bugs/logic, quality/maintainability, performance. Security flagged when a severe issue is obvious in the diff.
- **Repo-specific guidelines** — a `.github/code-review-guidelines.md` refines the built-in prompt with your team's rules, focus areas, severity scale, and format.
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

---

## How it works

On `pull_request` (opened, synchronize, reopened, ready_for_review), the
consumer workflow calls the reusable workflow here, which:

1. Skips draft PRs and cancels superseded runs for the same PR.
2. Fetches the PR diff via the GitHub API (no checkout needed). If the diff
   exceeds `max_diff_lines`, posts a skip comment and exits successfully.
3. Sends the diff in a single request to the configured model with an embedded
   review prompt, then posts the response as one advisory summary comment.

If the provider errors (bad key, no credit) or returns an empty response, the
job posts a short "review unavailable" comment and exits successfully — it
never fails the check or blocks the PR.

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

<div align="center">

**Every PR, read once before a human even looks. For cents.**

[Get started](#-get-started-in-5-minutes) · [See the pitch](docs/PITCH.md) · [Changelog](CHANGELOG.md)

</div>
