# code-review-bot

Automated, advisory code review for pull requests, powered by Claude
(`anthropics/claude-code-action`). Adopt in any repo with one small
workflow file.

- **Advisory:** the bot comments; humans decide. It never blocks merges —
  do not add the review job to branch protection required checks.
- **Focus:** bugs/logic, quality/maintainability, performance. Security is
  flagged only when a severe issue is obvious in the diff.
- **Language:** review comments are in English.
- **Cost controls:** drafts are skipped, superseded runs are cancelled on
  new pushes, and diffs above `max_diff_lines` (default 5000) are skipped
  with an explanatory comment.

## One-time setup (per org or account)

1. Get an Anthropic API key: <https://console.anthropic.com/>.
2. Store it as a secret named `ANTHROPIC_API_KEY`:
   - **Organization:** `gh secret set ANTHROPIC_API_KEY --org YOUR_ORG --visibility all`
     (repos then receive it via `secrets: inherit`).
   - **Personal account:** set it per repo:
     `gh secret set ANTHROPIC_API_KEY --repo YOUR_USER/YOUR_REPO`.
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
| `model` | string | `claude-opus-4-8` | Claude model used for the review |
| `extra_instructions` | string | `""` | Extra review instructions appended to the prompt (e.g. project-specific rules) |
| `max_diff_lines` | number | `5000` | Skip the review when the PR diff exceeds this many lines |

## Secrets

| Secret | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | yes | Anthropic API key; provided via `secrets: inherit` from the org/repo secret |

## Versioning

Consumers pin `@v1`. Semantic tags (`v1.0.0`, `v1.1.0`, …) are cut per
release and the floating `v1` tag moves to the latest compatible release.
Breaking changes ship as `v2`; existing consumers are unaffected until
they opt in.

## How it works

On `pull_request` (opened, synchronize, reopened, ready_for_review), the
consumer workflow calls the reusable workflow here, which:

1. Skips draft PRs and cancels superseded runs for the same PR.
2. Measures the diff; if above `max_diff_lines`, posts a skip comment and
   exits successfully.
3. Runs `anthropics/claude-code-action@v1` with embedded review
   guidelines. Claude posts inline comments on relevant lines plus one
   summary comment.

Failures (bad API key, timeouts) fail the job with a clear log, but since
the check is not required, the PR is never blocked.
