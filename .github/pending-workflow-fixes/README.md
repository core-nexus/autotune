# Pending workflow-directory fixes (ai-compliance review)

The automated ai-compliance fix run could not push its edits to any file under
`.github/workflows/`: the GitHub App token used by the workflow lacks the
`workflows` permission, so GitHub rejects any push that creates or updates a
file in that directory (both the workflow YAML **and** the helper scripts):

```
refusing to allow a GitHub App to create or update workflow
`.github/workflows/scripts/extract-pr-review-priority.sh`
without `workflows` permission
```

Everything **outside** `.github/workflows/` (the `ai-compliance.md` review
prompt and the README) was pushed normally. Every fix that touches a file under
`.github/workflows/` is captured in
[`workflow-fixes.patch`](./workflow-fixes.patch) so a maintainer with a
`workflow`-scoped token (or a personal access token) can apply them in one step.

The patch was verified end-to-end: it applies cleanly to `main`, and after
applying, `shellcheck` and the script test suite both pass.

## What the patch changes

- **`codebase-review.yml`**
  - Pins `--model` from the floating alias `opus` to the explicit id
    `claude-opus-4-8` (review + fix stages) for reproducible, auditable runs
    (finding item 3).
  - Requires an "AI-generated" disclosure block at the top of every review
    issue body, recording the model + action version — EU AI Act Art. 50
    transparency direction (finding item 1).
  - Requires a `Co-Authored-By: Claude (AI)` trailer on fix-stage commits and a
    model line in the PR body (findings item 3, item 7).
- **`claude-pr-review.yml`**
  - Pins `--model` to `claude-opus-4-8` (review + fix stages) (finding item 3).
  - Requires an AI-disclosure block at the top of every PR review comment
    (finding item 2).
  - Gates the `/claude-review` and `/claude-fix` comment triggers to
    `OWNER`/`MEMBER`/`COLLABORATOR` — abuse/cost control on a public repo
    (finding item 6).
  - Requires a `Co-Authored-By: Claude (AI)` trailer on fix-stage commits
    (finding item 7).
- **`scripts/extract-review-priority.sh`** and
  **`scripts/extract-pr-review-priority.sh`**
  - Stop silently coercing a missing/malformed AI verdict to `NONE`; an
    unparseable (empty) result now emits a `::warning::` instead of
    masquerading as a genuine "clean" review (finding item 4).
- **`scripts/tests/test-extract-priority.sh`** (new) — tests covering the
  explicit-NONE vs parse-failure distinction for both extraction scripts.
- **`scripts-test.yml`** (new) — runs `shellcheck` + the script tests in CI.

## How to apply

```bash
git apply .github/pending-workflow-fixes/workflow-fixes.patch
# verify
shellcheck .github/workflows/scripts/*.sh .github/workflows/scripts/tests/*.sh
.github/workflows/scripts/tests/test-extract-priority.sh
git commit -am "fix(ai-compliance): apply workflow-directory transparency/model/abuse/fail-loud fixes"
```

Once applied, this directory can be deleted.
