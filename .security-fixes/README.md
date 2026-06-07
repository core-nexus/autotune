# Security fix patches

This directory contains patch files for security fixes that the auto-review
bot cannot apply directly. GitHub Apps cannot create or update **any** file
under `.github/workflows/` (including the helper scripts and a new test
workflow) without an explicit `workflows` write permission, which this bot's
token does not have. Because this repository is almost entirely workflow
files, nearly every fix must be applied by a maintainer from the patch below.

## Applying a patch

From the repo root, on a fresh branch:

```bash
git checkout -b apply-security-fix-2026-06-07
git apply --index .security-fixes/2026-06-07-issue-105.patch
git commit -m "fix(security): apply 2026-06-07 review fixes (issue 105)"
git push -u origin HEAD
```

Then open a PR. After it merges, delete the corresponding `.patch` file in a
follow-up commit.

## Verifying a patch before applying

```bash
git apply --check .security-fixes/2026-06-07-issue-105.patch
```

The patch is self-contained — it only touches files in this repo and adds a
hermetic test suite (`tests/test-review-scripts.sh`) plus a lightweight runner
workflow (`.github/workflows/scripts-ci.yml`). After applying, run the tests:

```bash
bash tests/test-review-scripts.sh
```

## What `2026-06-07-issue-105.patch` fixes

Addresses every finding from issue 105 (`review(security): findings — 2026-06-07`):

- **item 1 (HIGH)** — Comment triggers (`/claude-review`, `/claude-fix`) now
  require `comment.author_association` ∈ {OWNER, MEMBER, COLLABORATOR}, so an
  arbitrary commenter on a public repo can no longer start the write-scoped
  autonomous agent.
- **item 2 (MEDIUM)** — `extract-pr-review-priority.sh` only honors a
  `MAXIMUM_FIX_PRIORITY:` marker from a bot-authored comment, so a human
  commenter cannot spoof the fix-stage gate.
- **item 3 (MEDIUM)** — Prompt-injection threat model documented in the README;
  the review stage stays read-only and the write-scoped fix stage is gated by
  item 1.
- **item 4 (MEDIUM)** — Third-party actions pinned to full commit SHAs (with
  version comments); `.github/dependabot.yml` added to keep the pins current.
- **item 5 (LOW)** — `resolve-review-area.sh` validates the area against an
  allowlist and rejects unknown/newline-bearing values before writing to
  `GITHUB_OUTPUT`.
- **item 6 (LOW)** — Confirmed `id-token: write` is required by
  `claude-code-action`'s GitHub App auth path; documented rather than removed.
- **item 7 (LOW)** — Helper scripts surface `gh` failures via `::warning::`
  instead of discarding stderr, while still failing closed to `NONE`.

Plus unit tests covering the changed security logic.
