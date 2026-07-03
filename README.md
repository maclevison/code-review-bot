# code-review-bot

Automated, advisory code review for pull requests, powered by any
OpenAI-compatible model through [OpenRouter](https://openrouter.ai/).
Adopt in any repo with one small workflow file.

- **Advisory:** the bot comments; humans decide. It never blocks merges —
  do not add the review job to branch protection required checks.
- **Cheap:** a single model call per PR posts one summary comment. Default
  model `moonshotai/kimi-k2.7-code-20260612` is code-specialized and still
  inexpensive; swap in any OpenRouter model via the `model` input.
- **Focus:** bugs/logic, quality/maintainability, performance. Security is
  flagged only when a severe issue is obvious in the diff.
- **Language:** review comments are in English.
- **Cost controls:** drafts are skipped, superseded runs are cancelled on
  new pushes, and diffs above `max_diff_lines` (default 5000) are skipped
  with an explanatory comment.

## One-time setup (per org or account)

1. Get an OpenRouter API key: <https://openrouter.ai/keys>. Add credit to
   your OpenRouter account.
2. Store it as a secret named `OPENROUTER_API_KEY`:
   - **Organization:** `gh secret set OPENROUTER_API_KEY --org YOUR_ORG --visibility all`
     (repos then receive it via `secrets: inherit`).
   - **Personal account:** set it per repo:
     `gh secret set OPENROUTER_API_KEY --repo YOUR_USER/YOUR_REPO`.
3. This repo must be callable by consumers:
   - Public repo: works as-is.
   - Private/internal repo in an org: Settings → Actions → General →
     Access → "Accessible from repositories in the organization".

## Adopt in a repo

Copy `templates/consumer-workflow.yml` to
`.github/workflows/code-review.yml` in the target repo and replace
`OWNER` with the user/org hosting this repo. That's it — the next
non-draft PR gets reviewed. Note: the repo hosting this workflow must
be named `code-review-bot`, or you must edit the `code-review-bot`
path segment in the consumer template to match your repo name.

## Inputs

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

## Repo-specific review guidelines

Drop a Markdown file at `.github/code-review-guidelines.md` in the repo you
want reviewed to define what the bot should focus on, what to ignore, the
severity scale, and the response format. The bot reads it at the PR's head
commit and appends it to its built-in prompt — the baseline still applies,
your file refines it. Copy `templates/code-review-guidelines.md` as a
starting point. No file → the bot uses its defaults.

## Secrets

| Secret | Required | Description |
|---|---|---|
| `OPENROUTER_API_KEY` | yes | OpenRouter API key; provided via `secrets: inherit` from the org/repo secret |

## Data handling & providers

The bot sends the PR diff to whatever endpoint `base_url` points at. Because
it speaks the OpenAI-compatible protocol, you are not tied to OpenRouter —
point it at whatever your security team approves:

- **OpenRouter (default)** — set `require_zero_retention: true` to route only
  to providers that don't retain data.
- **Azure OpenAI** — `base_url` to your Azure endpoint; the deployment name
  is the `model`.
- **AWS Bedrock** — via an OpenAI-compatible gateway (e.g. LiteLLM / Bedrock
  Access Gateway) in your own VPC.
- **Self-hosted** — vLLM, Ollama, or LiteLLM inside your network, so code
  never leaves your infrastructure.

The `OPENROUTER_API_KEY` secret is just the bearer token for `base_url` —
name aside, it carries whatever provider's key you configure. Only the diff
is sent; the bot never uploads the full repository.

## Observability

Each run writes a token-usage table (and cost, when the provider reports it)
to the GitHub Actions **job summary**, so spend is visible per PR without
extra tooling.

## Versioning

Consumers pin `@v2`. Semantic tags (`v2.0.0`, `v2.1.0`, …) are cut per
release and the floating `v2` tag moves to the latest compatible release.
Breaking changes ship as a new major tag; existing consumers are
unaffected until they opt in. (`v1` was the Claude-based engine.)

## How it works

On `pull_request` (opened, synchronize, reopened, ready_for_review), the
consumer workflow calls the reusable workflow here, which:

1. Skips draft PRs and cancels superseded runs for the same PR.
2. Fetches the PR diff via the GitHub API (no checkout needed). If the
   diff is above `max_diff_lines`, posts a skip comment and exits
   successfully.
3. Sends the diff in a single request to the configured OpenRouter model
   with an embedded review prompt, then posts the model's response as one
   advisory summary comment on the PR.

If the provider returns an error (bad key, no credit) or an empty
response, the job posts a short "review unavailable" comment and exits
successfully — it never fails the check or blocks the PR.
