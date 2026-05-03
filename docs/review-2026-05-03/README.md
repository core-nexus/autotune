# ai-compliance review fixes — patch artifact

This directory exists because the GitHub App identity that authors auto-fix
branches lacks the `workflows` permission. Anything under `.github/workflows/`
(including the shell scripts in `.github/workflows/scripts/`) is rejected
on push by the GitHub remote with:

```
refusing to allow a GitHub App to create or update workflow
.github/workflows/<file> without `workflows` permission
```

The patch in this directory bundles the unpushable changes so a human
maintainer can apply them by hand.

## What's in the patch

The patch (`workflow-prompt-changes.patch`) addresses items 1, 2, 3, 4, 7,
and 9 from the ai-compliance review issue (`review(ai-compliance): findings
— 2026-05-03`):

- **item 1 (MEDIUM)** — `extract-review-priority.sh` and
  `extract-pr-review-priority.sh` now distinguish "model said NONE" from
  "parse failed", emit `::warning::` annotations on parse failure, broaden
  the regex to tolerate whitespace/case drift, and validate captured values
  against the known set.
- **item 2 (MEDIUM)** — Workflow prompts now require a context-preserving
  closing comment (carried-forward vs. dropped findings, plus a verbatim
  copy of prior finding titles or commit messages) and a `superseded`
  label before any prior issue/PR is auto-closed.
- **item 3 (LOW)** — Issue bodies, PR descriptions, and PR-review comments
  must include an AI-generation disclosure footer.
- **item 4 (LOW)** — The resolved model ID is recorded in every output
  footer and in fix-stage commit trailers, so model-version regressions
  remain traceable after Actions log retention expires.
- **item 7 (LOW)** — Each `--dangerously-skip-permissions` line carries an
  inline comment explaining the unattended-CI rationale and the
  compensating controls (scoped tokens, branch-protected human merge).
- **item 9 (XLOW)** — `trigger-ci-workflows.sh` distinguishes "no such
  workflow" (benign default for the auto-detect mode) from auth/rate/outage
  failures; the latter become `::warning::` AND fail the step so the
  notify job fires.

The patch also adds three bash test suites under `tests/scripts/` that
verify the priority-extraction and CI-dispatch contracts. They are bundled
in the same patch because the test scripts depend on the script changes
landing together; pushing tests against unfixed scripts would fail.

## How to apply

```bash
git checkout review/ai-compliance-2026-05-03
git apply docs/review-2026-05-03/workflow-prompt-changes.patch

# Verify
bash tests/scripts/test-extract-review-priority.sh
bash tests/scripts/test-extract-pr-review-priority.sh
bash tests/scripts/test-trigger-ci-workflows.sh
shellcheck .github/workflows/scripts/*.sh tests/scripts/*.sh

git add .github/workflows tests
git commit -m "fix(ai-compliance): apply review/2026-05-03 workflow + script patch"
git push
```

A maintainer also wanted to gate these scripts with CI — a starter `ci.yml`
is included in the patch's commentary but commented out (the App couldn't
push it either). Add it once the patch lands.

## Items resolved directly in this PR

These changes did not touch `.github/workflows/` and are present in the
PR's commits, not the patch:

- **item 5 (LOW)** — `README.md` "Data Flow & Third-Party Processing".
- **item 6 (LOW)** — `README.md` "Known Limitations".
- **item 8 (XLOW)** — `.github/review-prompts/ai-compliance.md` cites
  EU AI Act Article 50 (final adopted text) instead of Article 52.
