# claude-prod

Production-grade Claude Code automation for GitHub repositories. A toolkit of
GitHub Actions workflows, a Cloudflare Worker, and reusable agent skills that put
Claude to work on a real codebase — reviewing code, QA-ing previews, fixing red
CI, triaging Sentry errors, writing changelogs, and shepherding PRs to merge.

**Everything here is modular.** Copy the pieces you want into your own repo and
skip the rest; the components share conventions but have no hard dependencies on
one another. Almost every workflow authenticates with a single
`CLAUDE_CODE_OAUTH_TOKEN` secret, which bills to Claude Code **plan** credits
rather than API credits.

## Repository map

| Component | Path | What it does |
|---|---|---|
| **Codebase Review** | `.github/workflows/codebase-review.yml` + `.github/review-prompts/` | Scheduled deep-dive audits across 15 focus areas → issues → auto-fix PRs |
| **PR Review** | `.github/workflows/claude-pr-review.yml` | Reviews every PR and auto-fixes findings; `/claude-review`, `/claude-fix` |
| **QA Review** | `.github/workflows/ai-qa-review.yml` | Opens a PR's preview deploy in a real browser and verifies it end-to-end; `/qa-review` |
| **CI Auto-Fix** | `.github/workflows/claude-auto-fix-ci.yml` | On CI failure, feeds logs to Claude to push a fix commit (ships **disabled**, opt-in) |
| **Changelog** | `.github/workflows/changelog.yml` | AI-written changelog entries, opened as a PR on a schedule |
| **@claude assistant** | `.github/workflows/claude.yml` | Mention `@claude` on any issue/PR and the agent responds |
| **Sentry Triage** | `.github/workflows/sentry-triage.yml` + `workers/sentry-triage/` | Cloudflare Worker bridges Sentry alerts → Claude opens a fix PR |
| **Skills** | `skills/` | Reusable Claude Code skills: `babysit`, `pr-merge-main`, `test-driven-development` |
| **Agent instructions** | `AGENTS.md` (`CLAUDE.md`, `GEMINI.md` symlinks) | Portable coding guidelines any agent can drop into a repo |

## Copying a piece into your repo

Each workflow file opens with a header comment documenting its triggers, required
secrets, and every knob worth turning — **read that header first; it is the
source of truth for setup.** The general recipe:

1. Copy the workflow YAML — plus any scripts it references from
   `.github/workflows/scripts/`, and `.github/review-prompts/` for codebase
   review — into your repo's `.github/`.
2. `chmod +x` any copied `*.sh` scripts.
3. Add the secrets the header names — at minimum `CLAUDE_CODE_OAUTH_TOKEN`
   ([how to mint one](https://docs.anthropic.com/en/docs/claude-code/github-actions)).
4. Adjust the header's config knobs (branch names, cron, CI workflow names,
   review areas) for your project, then commit on a branch and open a PR.

**Installing with an AI agent?** Paste this and let it work:

```
Install a component from https://github.com/core-nexus/claude-prod into this
repository:
1. Fetch the component's files: its workflow YAML, any scripts it references
   under .github/workflows/scripts/, and .github/review-prompts/ if you're
   installing the codebase review.
2. Read the header comment at the top of each copied workflow file — it lists the
   required secrets and the values to customize. Apply them for THIS repo.
3. chmod +x any copied .sh scripts.
4. Ensure CLAUDE_CODE_OAUTH_TOKEN (and any other secret the header names) is set
   under Settings → Secrets and variables → Actions.
5. Commit on a feature branch and open a PR — never push straight to main.
```

## Components

### Codebase Review — `codebase-review.yml`

A two-stage pipeline: **review → fix**.

1. **Review** — Claude audits the entire codebase against one focus area's
   checklist and opens a GitHub issue with findings grouped by severity.
2. **Fix** — when a finding is MEDIUM or higher, Claude edits code, runs your
   quality gates, and opens a PR.

Fifteen focus areas ship in `.github/review-prompts/`:

| Area | What it checks |
|---|---|
| **security** | Auth, authorization, injection, secrets, OWASP Top 10 |
| **code-quality** | Type safety, style, component architecture, dead code |
| **performance** | Query scalability, N+1 patterns, bundle size, memory leaks |
| **testing** | Coverage gaps, mock discipline, test quality, E2E |
| **error-handling** | Silent catches, error reporting, resilience patterns |
| **correctness** | Logic bugs, off-by-one errors, race conditions, wrong references |
| **privacy** | PII in logs, data minimization, consent, third-party data flows |
| **compliance** | GDPR, CCPA, cookie consent, data subject rights |
| **ai-compliance** | EU AI Act, transparency, bias, automated decision-making |
| **documentation** | Stale docs, missing API docs, CLAUDE.md accuracy |
| **dependency-health** | Vulnerabilities, outdated packages, license compliance, supply chain |
| **e-commerce** | Payments, subscriptions, webhooks, credit systems, billing math |
| **infrastructure** | CI/CD, pre-commit hooks, linting/formatting, build scripts, env hygiene |
| **architecture** | Schema/data-model changes, module boundaries, scalability of recent changes |
| **resilience** | Rate limits, timeouts, retries, idempotency, graceful degradation, blast radius |

Ships runnable via `workflow_dispatch` (pick one area or `all`). The weekly
`cron: '0 6 * * 0'` (Sunday 06:00 UTC) is commented out in the workflow —
uncomment it to schedule. Add a new area by dropping a `.md` in `review-prompts/`
(Objective → Checklist → Severity Guide) and registering it in the
`workflow_dispatch` options and `ALL_AREAS` in `resolve-review-area.sh`.

<details>
<summary><b>Copy-paste install block for an AI agent</b></summary>

```
Install the codebase-review system from https://github.com/core-nexus/claude-prod
into this repository:

1. Copy these into this repo (merge with existing .github/ if present):
   - .github/review-prompts/                       (all 15 .md files)
   - .github/workflows/codebase-review.yml
   - .github/workflows/scripts/resolve-review-area.sh
   - .github/workflows/scripts/extract-review-priority.sh
   - .github/workflows/scripts/trigger-ci-workflows.sh

2. chmod +x .github/workflows/scripts/*.sh

3. Adjust codebase-review.yml for this project:
   - Uncomment the `schedule:` cron to run weekly (default Sunday 06:00 UTC), or
     leave it manual (workflow_dispatch only).
   - Remove review areas that don't apply (e.g. e-commerce.md with no payments,
     ai-compliance.md with no AI features) and drop them from the
     workflow_dispatch options and ALL_AREAS in resolve-review-area.sh.
   - In trigger-ci-workflows.sh set WORKFLOWS to this project's CI workflow
     filenames, e.g. "ci.yml test.yml checks.yml".

4. Set the CLAUDE_CODE_OAUTH_TOKEN secret
   (Settings → Secrets and variables → Actions).

5. Create the auto-review label:
   gh label create auto-review --description "Automated codebase review" --color "0E8A16"

6. Commit on a feature branch and open a PR.
```

</details>

### PR Review — `claude-pr-review.yml`

Reviews every PR on open / ready-for-review, then auto-fixes findings at or above
`MAXIMUM_FIX_PRIORITY` (default `LOW`). Comment `/claude-review` to re-review or
`/claude-fix` to force a fix pass. The fix stage pushes commits to the PR branch
and monitors CI until green. Docs/text-only PRs are skipped.

### QA Review — `ai-qa-review.yml`

Opens a PR's preview deployment in a real browser and verifies the change works
end-to-end — the behavioral complement to the code-level PR review, and safe to
run in parallel with it. Runs on open / ready-for-review; comment `/qa-review` to
re-run against new commits. Point `wait-for-preview-url.sh` at wherever your
deploy bot posts the preview URL.

### CI Auto-Fix — `claude-auto-fix-ci.yml`

When a CI run fails on a PR, feeds the failing job logs to Claude, which pushes a
fix commit and lets CI re-run until green. **Ships disabled** — it self-pushes
commits, so it does nothing until you set the repo variable
`ENABLE_AUTO_FIX_CI=true` and list your CI workflow's `name:` under
`on.workflow_run`. A `[auto-fix-ci]` commit marker caps it at 5 attempts per
branch; it only ever adds new commits and refuses to touch the default branch.

### Changelog — `changelog.yml`

On a schedule (default Mon/Thu 15:00 UTC) collects PRs merged since the last
entry and asks Claude to write user-facing `CHANGELOG.md` entries
(Keep-a-Changelog style, newest-first). Always opened as a reviewable PR — never
pushed to the base branch.

### @claude assistant — `claude.yml`

Mention `@claude` in an issue, PR, or review comment and the agent reads context,
makes changes, and pushes commits or opens PRs. Gated to OWNER / MEMBER /
COLLABORATOR so fork PRs can't run it with your secrets.

### Sentry Triage — `sentry-triage.yml` + `workers/sentry-triage/`

A Cloudflare Worker (`workers/sentry-triage/`) receives Sentry webhooks, verifies
and normalizes them, deduplicates aggressively (four stacked layers), and fires a
GitHub `repository_dispatch`. The `sentry-triage.yml` workflow then runs Claude to
investigate and, if the bug is worth fixing, opens a PR with a regression test
plus the fix. Full architecture and operator guide:
[`docs/sentry-triage/`](docs/sentry-triage/README.md).

### Skills — `skills/`

Reusable [Claude Code skills](https://docs.anthropic.com/en/docs/claude-code):

- **`babysit`** — scans your open PRs and takes one action each: resolve merge
  conflicts, retrigger stuck CI, and nudge the review/fix/QA pipeline forward.
  Built to run inside a `/loop`.
- **`pr-merge-main`** — merges the default branch into a working branch,
  resolving conflicts thoughtfully.
- **`test-driven-development`** — enforces write-the-test-first discipline.

### Agent instructions — `AGENTS.md`

Portable engineering guidelines for AI coding agents: simplicity, surgical
changes, fail-loud error handling, no-mocks testing, and the Git/PR/CI workflow.
`CLAUDE.md` and `GEMINI.md` symlink to it, so Claude Code, Gemini, and any
`AGENTS.md`-aware tool pick up the same rules. Drop it into any repo root.

## Conventions

### Severity & priority

Findings are ranked, and one threshold — `MAXIMUM_FIX_PRIORITY` — decides what
gets auto-fixed versus left for a human:

| Priority | Meaning | Auto-fixed? |
|---|---|---|
| NONE | Clean, no issues | No |
| XLOW | Trivial nits | No |
| LOW | Minor issues | PR review: yes · Codebase review: no |
| MEDIUM | Real issues | Yes |
| HIGH | Critical issues | Yes |

### Bring your own CLAUDE.md

Any workflow that reviews or edits code reads your repo's root `CLAUDE.md` (or
`AGENTS.md`) and follows it — the cleanest way to steer Claude's behavior without
editing the prompts.

## Cost

Each Claude run uses Claude Code plan credits (Opus by default). The codebase
review is the heaviest piece — up to 15 review + 15 fix sessions a week if you
enable every area on the weekly schedule. To trim cost: delete review areas you
don't need, run less often, or switch a workflow to `--model sonnet` for a
~3–5× reduction at some quality tradeoff.

## License

MIT © Superluminal Systems. See [LICENSE](LICENSE).
