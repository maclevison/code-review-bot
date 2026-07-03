<!--
Copy this file into the repo you want reviewed, at:
    .github/code-review-guidelines.md
(or point the `guidelines_path` input elsewhere).

The code-review bot reads it at the PR's head commit and appends it to its
built-in review prompt. The built-in baseline (bugs/logic, quality,
performance; advisory tone; English; one summary comment citing file:line)
still applies — this file refines and adds to it. Delete the guidance you
don't need and edit the rest. Everything here is instructions to the model,
so write it as directions, not prose.

Higher-priority alternative — REVIEW.md:
    Instead of (or in addition to) this file, you can drop a `REVIEW.md` at the
    repo root. Following the Claude Code Review convention, REVIEW.md is treated
    as HIGHEST-PRIORITY review-only instructions: injected verbatim and
    overriding the built-in defaults, this guidelines file, and
    extra_instructions when they conflict. REVIEW.md loads from the TARGET
    branch (only merged rules apply); this guidelines file loads at the PR head.
    Either, both, or neither may exist. Use REVIEW.md for hard rules you always
    want honored; use this guidelines file for softer, additive refinements.

Severity markers:
    When you want the bot's severity tally (the `Findings:` line and the
    machine-readable `review-severity` marker in the job summary) to reflect
    your findings, have the review mark each one with these exact emoji:
        🔴  important
        🟡  nit
        🟣  pre_existing
-->

# Code review guidelines

## Project context
<!-- One or two lines so the reviewer knows the stack and what matters. -->
- Stack: <e.g. Nuxt 3 + Nitro API, PostgreSQL, multi-tenant SaaS>.
- Critical invariant: <e.g. every DB query must be scoped by tenant_id>.

## Pay extra attention to
<!-- The things a generic reviewer would miss. Be specific. -->
- Tenant isolation: flag any query, cache key, or route that isn't scoped
  to the current tenant.
- Auth: flag missing authorization checks on new endpoints.
- Money/dates: flag unrounded currency math or naive timezone handling.

## Do not flag
<!-- Cut the noise so findings stay high-signal. -->
- Formatting/style already enforced by Prettier/ESLint.
- Missing tests for trivial or generated code.
- Subjective naming preferences.

## Severity
<!-- How you want findings ranked. Use the built-in emoji so the tally counts them. -->
- **🔴 Important:** data loss, security hole, breaks a critical invariant above.
- **🟡 Nit:** minor; keep to at most a few.
- **🟣 Pre-existing:** a bug visible in the diff context but NOT introduced by
  this PR; flag it, don't count it against the change.

## Response format
<!-- How the single summary comment should be structured. -->
- Open with a one-line tally in WORDS (no emoji), e.g. `2 important · 1 nit`, or
  `No blocking issues` when there are no 🔴/🟣 findings.
- Then list each finding prefixed with its 🔴/🟡/🟣 marker: `path:line` + what's
  wrong + the suggested change, one line each.
- Even when there is nothing to flag, do NOT output the bare tally alone — add
  one line naming what you checked (e.g. "verified tenant scoping, no N+1,
  inputs validated"), so a clean review still shows the review happened.
