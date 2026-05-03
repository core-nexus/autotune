# E-Commerce & Payments Review

## Status for this repository

**Not applicable.** This repository (`core-nexus/autotune`) is a consumer
install of the claude-code-review system and contains no payments code:

- No payment processor integration (Stripe, Paddle, Lemon Squeezy, Braintree, etc.)
- No webhook handlers (no signature verification, no idempotency layer)
- No subscription, billing, invoice, or entitlement logic
- No credit / token / balance accounting
- No checkout, pricing, currency, or money math
- No customer / user / account model
- No database, no persisted state of any kind

The previous full e-commerce review (issue item 11, 2026-05-03) confirmed
this and returned `MAXIMUM_FIX_PRIORITY:NONE`. The codebase has not gained
any payments surface area since.

## Instructions for the reviewer

1. **Spot-check** that no e-commerce code has been introduced since the
   last review. From the repo root, run:

   ```bash
   grep -r -l -i -E 'stripe|paddle|braintree|lemonsqueez|webhook|subscription|invoice|checkout|entitlement|billing' \
     --exclude-dir=.git \
     --include='*.js' --include='*.ts' --include='*.py' --include='*.go' \
     --include='*.rb' --include='*.java' --include='*.kt' --include='*.rs' \
     --include='*.cs' --include='*.php' --include='*.sql' --include='*.json' \
     --include='*.yml' --include='*.yaml' --include='*.toml' \
     2>/dev/null
   ```

   If the only matches are inside `.github/review-prompts/` (review prompt
   text itself) or `README.md` (documentation), proceed to step 2.

2. **Create a clean issue.** Title:
   `review(e-commerce): clean — YYYY-MM-DD`. Body should briefly note that
   the spot-check confirmed no payments code, link back to issue item 11
   for the full prior analysis, and end with the priority line.

3. **End the issue body with exactly:**

   ```
   MAXIMUM_FIX_PRIORITY:NONE
   ```

4. Close the issue immediately after creating it.

If step 1 *does* find new payments code (i.e. this repo has gained a real
payments surface), discard this stub and perform the full audit using the
canonical e-commerce checklist from
[claude-code-review](https://github.com/core-nexus/claude-code-review/blob/main/.github/review-prompts/e-commerce.md):
webhook integrity, subscription state machine, credit atomicity, cost
calculation, checkout flows, data consistency, currency/integer math, and
the standard severity guide. Then notify maintainers that this stub
should be replaced with the full checklist.

## Why this file is a stub

Per the project's own README ("Configuration → Remove Irrelevant Review
Areas"), repos with no payments should remove this area entirely:

> **No payments?** Delete `e-commerce.md` and remove `e-commerce` from
> the workflow_dispatch options and `ALL_AREAS` in `resolve-review-area.sh`

Fully removing the area requires editing `.github/workflows/codebase-review.yml`
and `.github/workflows/scripts/resolve-review-area.sh`, both of which sit
under `.github/workflows/` and therefore require the GitHub `workflows`
permission to push. The automated fix workflow's token does not hold that
permission, so it cannot land those edits. A maintainer should complete
the cleanup in a follow-up by:

1. Deleting this file.
2. Removing the `e-commerce` entry from `workflow_dispatch.inputs.review_area.options`
   in `.github/workflows/codebase-review.yml`.
3. Removing `"e-commerce"` from `ALL_AREAS` in
   `.github/workflows/scripts/resolve-review-area.sh`.
4. Optionally removing the `e-commerce` row from the review-areas table
   in `README.md`.

Until that happens, this stub keeps the weekly scheduled e-commerce
review cheap (a single grep + a clean issue) instead of the full
multi-section deep-dive against criteria that have nothing to evaluate.
