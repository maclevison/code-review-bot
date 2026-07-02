# Code Review Bot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reusable GitHub Actions workflow that has Claude review every pull request in adopting repos and post advisory comments.

**Architecture:** This repo is the central repo. It hosts a reusable workflow (`on: workflow_call`) that wraps `anthropics/claude-code-action@v1`. Consumer repos adopt it with one ~10-line workflow file. Review guidelines are embedded inline in the reusable workflow's prompt (no cross-repo file reads at runtime). Validation is `actionlint` locally + in CI, and an end-to-end sandbox repo with fixture PRs.

**Tech Stack:** GitHub Actions (reusable workflows), `anthropics/claude-code-action@v1`, `gh` CLI, `actionlint`.

**Spec:** `docs/superpowers/specs/2026-07-02-code-review-bot-design.md`

## Global Constraints

- Review comments are in **English**; advisory tone; the review job is never a required check.
- Default model: `claude-opus-4-8`, overridable via the `model` input.
- Pin actions: `anthropics/claude-code-action@v1`, `actions/checkout@v4`, `raven-actions/actionlint@v2`.
- Job permissions are exactly: `contents: read`, `pull-requests: write`, `issues: write`, `id-token: write`, `actions: read`. Nothing more.
- Draft PRs are never reviewed. Superseded runs on the same PR are cancelled (`cancel-in-progress`).
- Default diff limit: 5000 lines (`max_diff_lines` input). Oversized PRs get a skip comment and the job exits successfully.
- The API key secret is named `ANTHROPIC_API_KEY` and is never hardcoded or echoed.
- In `run:` blocks, pass all `${{ }}` expressions through `env:` vars (actionlint/shellcheck-clean, avoids injection).
- `$OWNER` below means the GitHub user/org that will host the repos. Export it once per shell session: `export OWNER=<your-github-user-or-org>`. It is the only allowed variable of this kind.

---

### Task 1: Repo scaffold + actionlint CI

**Files:**
- Create: `.github/workflows/lint.yml`
- Create: `README.md` (skeleton; completed in Task 3)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a repo where `actionlint` (local and CI) validates every file under `.github/workflows/`. Later tasks run `actionlint` as their test step.

- [ ] **Step 1: Install actionlint locally (the "test runner" for this project)**

Run: `command -v actionlint || brew install actionlint`
Expected: `actionlint` available on PATH. Verify: `actionlint --version` prints a version.

- [ ] **Step 2: Run actionlint before any workflow exists (baseline)**

Run: `actionlint`
Expected: exits 0 silently (no workflow files yet — trivially passing baseline).

- [ ] **Step 3: Write the lint CI workflow**

Create `.github/workflows/lint.yml`:

```yaml
name: Lint

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  actionlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: raven-actions/actionlint@v2
```

- [ ] **Step 4: Run actionlint to validate it**

Run: `actionlint`
Expected: exits 0, no output.

- [ ] **Step 5: Write the README skeleton**

Create `README.md`:

```markdown
# code-review-bot

Automated, advisory code review for pull requests, powered by Claude
(`anthropics/claude-code-action`). Adopt in any repo with one small
workflow file.

- **Advisory:** the bot comments; humans decide. It never blocks merges.
- **Focus:** bugs/logic, quality/maintainability, performance.
- **Language:** review comments are in English.

## Adoption

See `templates/consumer-workflow.yml`. Full setup guide below.

_(Setup guide written in a later task.)_
```

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/lint.yml README.md
git commit -m "feat: scaffold repo with actionlint CI and README skeleton"
```

---

### Task 2: Reusable review workflow

**Files:**
- Create: `.github/workflows/claude-review.yml`

**Interfaces:**
- Consumes: actionlint setup from Task 1.
- Produces: reusable workflow callable as `$OWNER/code-review-bot/.github/workflows/claude-review.yml@v1` with this contract:
  - inputs: `model` (string, default `claude-opus-4-8`), `extra_instructions` (string, default `""`), `max_diff_lines` (number, default `5000`)
  - secrets: `ANTHROPIC_API_KEY` (required)
  - trigger context: must be called from a `pull_request` event.

- [ ] **Step 1: Write the reusable workflow**

Create `.github/workflows/claude-review.yml`:

```yaml
name: Claude Code Review

on:
  workflow_call:
    inputs:
      model:
        description: "Claude model used for the review"
        type: string
        required: false
        default: "claude-opus-4-8"
      extra_instructions:
        description: "Extra review instructions appended to the prompt"
        type: string
        required: false
        default: ""
      max_diff_lines:
        description: "Skip the review when the PR diff exceeds this many lines"
        type: number
        required: false
        default: 5000
    secrets:
      ANTHROPIC_API_KEY:
        required: true

jobs:
  review:
    # Never review drafts. Advisory by design: this job must not be made a
    # required status check.
    if: github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    concurrency:
      group: claude-review-${{ github.event.pull_request.number }}
      cancel-in-progress: true
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
      actions: read
    steps:
      - name: Check diff size
        id: diff
        env:
          GH_TOKEN: ${{ github.token }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          REPO: ${{ github.repository }}
          MAX_LINES: ${{ inputs.max_diff_lines }}
        run: |
          lines=$(gh pr diff "$PR_NUMBER" --repo "$REPO" | wc -l | tr -d ' ')
          echo "Diff has ${lines} lines (limit: ${MAX_LINES})"
          if [ "$lines" -gt "$MAX_LINES" ]; then
            gh pr comment "$PR_NUMBER" --repo "$REPO" --body \
              ":robot: Claude review skipped: the diff has ${lines} lines, above the ${MAX_LINES}-line limit. Split the PR or raise \`max_diff_lines\` to get a review."
            echo "skip=true" >> "$GITHUB_OUTPUT"
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Checkout PR
        if: steps.diff.outputs.skip == 'false'
        uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - name: Claude review
        if: steps.diff.outputs.skip == 'false'
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            You are an automated code reviewer. Fetch this pull request's diff
            (`gh pr diff`) and review it.

            Focus, in priority order:
            1. Bugs and logic errors — edge cases, null/undefined handling,
               incorrect conditions, off-by-one errors, race conditions.
            2. Quality and maintainability — naming, duplication, complexity,
               adherence to the project's existing patterns, missing tests for
               changed behavior.
            3. Performance — N+1 queries, expensive loops, unnecessary
               allocations, blocking calls.

            Rules:
            - Comment in English. Advisory tone — you never block the merge.
            - Prioritize meaningful findings over nitpicks. Do not post
              praise-only or restate-the-diff comments.
            - For each specific finding, create an inline comment anchored to
              the relevant lines using the inline-comment tool.
            - Post exactly one summary comment (`gh pr comment`) with a brief
              overview; cite `file:line` for each finding you mention.
            - If the diff makes a severe security issue obvious, flag it, but
              do not actively hunt for security issues.
            - If you find nothing worth raising, post only the summary comment
              saying the changes look good.

            ${{ inputs.extra_instructions }}
          claude_args: |
            --model ${{ inputs.model }}
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
```

- [ ] **Step 2: Run actionlint to validate it**

Run: `actionlint`
Expected: exits 0, no output. If it reports shellcheck issues in the `Check diff size` step, fix them (all expressions must flow through `env:`, per Global Constraints).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/claude-review.yml
git commit -m "feat: add reusable Claude review workflow"
```

---

### Task 3: Consumer template + adoption README

**Files:**
- Create: `templates/consumer-workflow.yml`
- Modify: `README.md` (replace skeleton body with the full guide below)

**Interfaces:**
- Consumes: the workflow contract from Task 2 (path, inputs `model`/`extra_instructions`/`max_diff_lines`, secret `ANTHROPIC_API_KEY`).
- Produces: `templates/consumer-workflow.yml`, the exact file adopting repos copy to `.github/workflows/code-review.yml`.

- [ ] **Step 1: Write the consumer template**

Create `templates/consumer-workflow.yml`:

```yaml
# Copy this file to .github/workflows/code-review.yml in your repo.
# Replace OWNER with the user/org hosting code-review-bot.
name: Code Review

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

jobs:
  review:
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
      actions: read
    uses: OWNER/code-review-bot/.github/workflows/claude-review.yml@v1
    secrets: inherit
    # Optional overrides:
    # with:
    #   model: claude-sonnet-5
    #   extra_instructions: "Pay extra attention to database migrations."
    #   max_diff_lines: 8000
```

- [ ] **Step 2: Validate the template with actionlint**

Run: `actionlint templates/consumer-workflow.yml`
Expected: exits 0. (actionlint flags the literal `OWNER/...` `uses:` reference only if malformed; the placeholder form `OWNER/code-review-bot/...@v1` is syntactically valid.)

- [ ] **Step 3: Write the full README**

Replace the entire contents of `README.md` with:

```markdown
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
non-draft PR gets reviewed.

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
```

- [ ] **Step 4: Run actionlint over the repo again**

Run: `actionlint`
Expected: exits 0.

- [ ] **Step 5: Commit**

```bash
git add templates/consumer-workflow.yml README.md
git commit -m "feat: add consumer workflow template and adoption guide"
```

---

### Task 4: Publish + version tags

**Files:**
- Create: `CHANGELOG.md`

**Interfaces:**
- Consumes: completed repo from Tasks 1–3.
- Produces: the repo published on GitHub as `$OWNER/code-review-bot` with tags `v1.0.0` and floating `v1` — the reference the consumer template's `uses:` line resolves against.

- [ ] **Step 1: Write the changelog**

Create `CHANGELOG.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add changelog for v1.0.0"
```

- [ ] **Step 3: Create the GitHub repo and push**

Run:

```bash
export OWNER=<your-github-user-or-org>
gh repo create "$OWNER/code-review-bot" --public --source . --push
```

Expected: repo created, `main` pushed. (Public per the setup guide; a private org repo needs the Actions access setting from the README instead.)

- [ ] **Step 4: Tag v1.0.0 and floating v1, push tags**

```bash
git tag v1.0.0
git tag v1
git push origin v1.0.0 v1
```

Expected: both tags visible on GitHub (`gh api "repos/$OWNER/code-review-bot/tags" --jq '.[].name'` lists `v1` and `v1.0.0`).

- [ ] **Step 5: Verify lint CI is green**

Run: `gh run watch --repo "$OWNER/code-review-bot" --exit-status`
Expected: the `Lint` workflow run for the push completes successfully (exit 0).

---

### Task 5: End-to-end validation in a sandbox repo

**Files:**
- Create (in a separate sandbox repo, not this one): `.github/workflows/code-review.yml`, `src/discount.js`

**Interfaces:**
- Consumes: published `$OWNER/code-review-bot@v1` (Task 4) and `templates/consumer-workflow.yml` (Task 3).
- Produces: verified e2e behavior — review comments on a planted-bug PR, no run on drafts, skip comment on oversized diffs.

- [ ] **Step 1: Create the sandbox repo**

```bash
export OWNER=<your-github-user-or-org>
mkdir -p /tmp/review-bot-sandbox && cd /tmp/review-bot-sandbox
git init -b main
echo "# review-bot-sandbox" > README.md
git add . && git commit -m "init"
gh repo create "$OWNER/review-bot-sandbox" --private --source . --push
```

Expected: sandbox repo exists on GitHub.

- [ ] **Step 2: Set the API key secret on the sandbox**

Run: `gh secret set ANTHROPIC_API_KEY --repo "$OWNER/review-bot-sandbox"`
(paste the key when prompted; org accounts can use the org secret instead)
Expected: `gh secret list --repo "$OWNER/review-bot-sandbox"` shows `ANTHROPIC_API_KEY`.

- [ ] **Step 3: Add the consumer workflow (copied from the template, OWNER filled in)**

Create `.github/workflows/code-review.yml` in the sandbox with the exact contents of `templates/consumer-workflow.yml`, replacing `OWNER` with the real value. Then:

```bash
git add .github/workflows/code-review.yml
git commit -m "ci: adopt code-review-bot"
git push
```

- [ ] **Step 4: Open a PR with a planted off-by-one bug**

Create `src/discount.js`:

```js
// Applies tiered discounts. BUG (planted): `>` should be `>=`, so an order
// of exactly 100 gets no discount; and the loop is O(n^2) on purpose.
function applyDiscount(total) {
  if (total > 100) {
    return total * 0.9;
  }
  return total;
}

function sumOrders(orders) {
  let sum = 0;
  for (let i = 0; i < orders.length; i++) {
    for (let j = 0; j < orders.length; j++) {
      if (i === j) sum += orders[i].total;
    }
  }
  return sum;
}

module.exports = { applyDiscount, sumOrders };
```

```bash
git checkout -b planted-bug
git add src/discount.js
git commit -m "feat: add discount helpers"
git push -u origin planted-bug
gh pr create --title "Add discount helpers" --body "Adds discount calculation." --repo "$OWNER/review-bot-sandbox"
```

- [ ] **Step 5: Verify the review**

Run: `gh run watch --repo "$OWNER/review-bot-sandbox" --exit-status`, then
`gh pr view 1 --repo "$OWNER/review-bot-sandbox" --comments`.

Expected:
- Run succeeds.
- At least one inline/summary finding mentioning the `>` vs `>=` boundary at 100, and one mentioning the O(n²) loop in `sumOrders`.
- Comments are in English, advisory tone, exactly one summary comment.

If findings are weak or off-target, tune the prompt in `claude-review.yml` (central repo), re-tag (`git tag -f v1 && git push -f origin v1`), and push a new commit to the PR to re-trigger.

- [ ] **Step 6: Verify draft PRs are skipped**

```bash
git checkout main && git checkout -b draft-test
echo "console.log('draft');" > src/draft.js
git add . && git commit -m "wip" && git push -u origin draft-test
gh pr create --draft --title "WIP draft" --body "draft" --repo "$OWNER/review-bot-sandbox"
```

Expected: `gh run list --repo "$OWNER/review-bot-sandbox" --limit 3` shows the Code Review workflow for this PR was **skipped** (job-level `if` false) — no Claude run, no comments on the draft PR.

- [ ] **Step 7: Verify oversized diffs are skipped with a comment**

```bash
git checkout main && git checkout -b big-diff
seq 1 6000 | sed 's/^/console.log(/; s/$/);/' > src/big.js
git add . && git commit -m "feat: big generated file" && git push -u origin big-diff
gh pr create --title "Big diff" --body "oversized" --repo "$OWNER/review-bot-sandbox"
```

Expected: the run **succeeds** (not fails), and the PR has a single comment: "Claude review skipped: the diff has N lines, above the 5000-line limit…". No review comments.

- [ ] **Step 8: Record results and close fixtures**

Close the three PRs (`gh pr close 1 2 3 --repo "$OWNER/review-bot-sandbox"` — adjust numbers). Keep the sandbox repo for future prompt-tuning regression checks. If any expectation failed, fix in the central repo, move the `v1` tag, and re-run the relevant step before considering this task done.
