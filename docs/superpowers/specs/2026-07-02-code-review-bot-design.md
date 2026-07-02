# Code Review Bot — Design

**Date:** 2026-07-02
**Status:** Approved

## Goal

An automated code reviewer for GitHub pull requests. When a PR is opened or updated in any participating repository, Claude reviews the diff and posts review comments. The review is advisory — it never blocks merges.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Detection/integration | GitHub Action (`on: pull_request`) | No server to run; config lives in the repo; runs on GitHub's runners |
| Review engine | Official `anthropics/claude-code-action` | Maintained by Anthropic; less code to write and own |
| Distribution | Reusable workflow in a central org repo | One-line adoption per repo; prompt, rules, and version centralized |
| Review focus | Bugs/logic, quality/maintainability, performance | Security explicitly out of primary scope (may surface incidentally) |
| Merge gate | Advisory only — never a required check | Safe adoption; humans decide |
| Comment language | English | Team standard |
| Default model | `claude-opus-4-8` | Strongest reasoning for review; overridable via input |

## Architecture

A central repository (working name `code-review-bot`) hosts a **reusable workflow** (`on: workflow_call`). Consumer repos reference it with a ~6-line workflow file.

```
org/code-review-bot                        ← central repo (this project)
├── .github/workflows/claude-review.yml    ← reusable workflow (the engine)
├── templates/consumer-workflow.yml        ← copy-paste snippet for adopting repos
├── README.md                              ← setup + adoption guide
└── CHANGELOG.md                           ← release notes

consumer-repo/.github/workflows/code-review.yml   ← ~6 lines
```

Consumer workflow shape:

```yaml
name: Code Review
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
jobs:
  review:
    uses: org/code-review-bot/.github/workflows/claude-review.yml@v1
    secrets: inherit
```

### Secrets

`ANTHROPIC_API_KEY` stored as an **organization-level secret**, inherited by consumer jobs via `secrets: inherit`. Never hardcoded.

### Versioning

- Semantic tags (`v1.0.0`, `v1.1.0`, …).
- Floating major tag `v1` moved to the latest compatible release; consumers pin `@v1`.
- Breaking changes ship as `v2` — existing consumers unaffected until they opt in.

## Data flow

1. PR opened/updated (`opened`, `synchronize`, `reopened`, `ready_for_review`) in a consumer repo. Draft PRs are skipped.
2. Consumer workflow calls the reusable workflow at `@v1` with `secrets: inherit`.
3. Reusable workflow checks out the PR head.
4. `anthropics/claude-code-action` runs with the PR diff plus the review guidelines embedded in the reusable workflow's prompt. (Guidelines live inline in the YAML rather than a separate file: at runtime the checkout is of the *consumer* repo, so reading a file from the central repo would require cross-repo access — public repo or an extra PAT. Inline avoids that dependency.)
5. Claude posts inline comments on relevant hunks plus one summary comment on the PR.
6. Job completes. It is **not** a required status check, so it can never block merge.

### Concurrency and cost controls

- `concurrency: pr-review-${{ github.event.pull_request.number }}` with `cancel-in-progress: true` — a new push cancels an in-flight review of the same PR.
- Draft PRs never trigger a review.
- Optional inputs for path filtering and a max-diff-size guard for very large PRs.
- `permissions: contents: read, pull-requests: write` — least privilege.

## Components

| Component | Responsibility |
|---|---|
| `claude-review.yml` (reusable workflow) | The engine. Accepts optional inputs (`model`, `extra_instructions`, max diff size), runs the action, embeds the review guidelines in its prompt |
| Review guidelines (inline in `claude-review.yml`) | Reviewer instruction: focus on bugs/logic, quality/maintainability, performance; comment in English; advisory tone; prioritize meaningful findings over nitpicks; cite `file:line`; skip praise-only comments |
| `templates/consumer-workflow.yml` | Copy-paste onboarding snippet |
| `README.md` | How to create the org secret, adopt in a repo, customize inputs |

## Review behavior

- **In scope:** logic errors, edge cases, null/undefined handling, wrong conditions, race conditions; naming, duplication, complexity, adherence to project patterns, missing tests; N+1 queries, expensive loops, unnecessary allocations, blocking calls.
- **Out of primary scope:** dedicated security auditing. If the diff makes a severe security issue obvious, the reviewer may flag it, but security is not a review dimension it hunts for.
- **Tone:** advisory, concise, in English. Inline comments anchored to the relevant lines; one summary comment with an overview.

## Error handling

- Missing/invalid API key, API timeout, or action failure → job fails with a clear log message. Because the check is not required, the PR is never blocked.
- Oversized diff beyond the guard → job posts a short comment (or logs) explaining the review was skipped, and exits successfully.

## Testing

- YAML workflows have no unit tests; validation is end-to-end.
- A **sandbox repository** adopts the workflow and hosts fixture PRs: one with a planted logic bug, one with a code smell, one oversized diff. Verify the bot comments correctly, skips drafts, and cancels superseded runs.
- Lint workflows with `actionlint` in CI of the central repo.

## Out of scope (YAGNI)

- Blocking merge / severity gates
- Own server, webhooks, polling
- Static-analysis (linter) integration
- Multi-language comment output
- Review of non-PR events (pushes, issues)
