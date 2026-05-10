# Claude Code Review

Automated codebase review system powered by Claude. Runs weekly deep-dive audits across 12 focus areas, finds issues, and auto-fixes them via pull requests.

## What It Does

A two-stage GitHub Actions pipeline:

1. **Review Stage** — Claude reads your entire codebase against a specific review checklist, creates a GitHub issue with findings organized by severity
2. **Fix Stage** — If MEDIUM+ severity issues are found, Claude automatically edits code, runs your quality gates, and opens a PR with fixes

It also includes a **PR review workflow** that automatically reviews every pull request and can auto-fix issues it finds.

### Review Areas

| Area | What It Checks |
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

### Schedule

All reviews are dispatched together every **Sunday at 06:00 UTC** (with up to 3 areas running concurrently — see `max-parallel` in `codebase-review.yml`). You can also trigger any review manually via `workflow_dispatch`.

## Setup

### Prerequisites

- A GitHub repository
- A [Claude Code OAuth token](https://docs.anthropic.com/en/docs/claude-code/github-actions) (`CLAUDE_CODE_OAUTH_TOKEN` secret)

### Quick Install (Copy-Paste for Claude)

**Copy this entire block into Claude Code (or any AI coding agent) and let it install the system into your repo:**

---

```
Install the claude-code-review system from https://github.com/core-nexus/claude-code-review into this repository. Here's what to do:

1. Clone or fetch the review system files from https://github.com/core-nexus/claude-code-review

2. Copy these directories into this repo (merge with existing .github/ if present):
   - .github/review-prompts/  (all 12 .md files)
   - .github/workflows/codebase-review.yml
   - .github/workflows/claude-pr-review.yml
   - .github/workflows/scripts/  (all 4 .sh files)

3. Make the shell scripts executable:
   chmod +x .github/workflows/scripts/*.sh

4. Review the workflow files and adjust for this project:
   - In codebase-review.yml: verify the cron schedule works for this team
     (default: Sunday 06:00 UTC)
   - In trigger-ci-workflows.sh: set WORKFLOWS to match this project's actual
     CI workflow filenames (e.g., "ci.yml" or "test.yml" or "checks.yml")
   - If this project uses Slack, add the SLACK_WEBHOOK_URL secret and
     replace the notify job's echo step with the slackapi/slack-github-action
   - Remove review areas that don't apply (e.g., remove e-commerce.md if there's
     no payment system, remove ai-compliance.md if there's no AI features) and
     update the workflow_dispatch options and ALL_AREAS in resolve-review-area.sh

5. Ensure the CLAUDE_CODE_OAUTH_TOKEN secret is set in the repo's GitHub
   Actions secrets (Settings → Secrets and variables → Actions)

6. Create the `auto-review` label in the repo:
   gh label create auto-review --description "Automated codebase review" --color "0E8A16"

7. Commit everything on a feature branch and open a PR.
```

---

### Manual Install

1. Copy the `.github/review-prompts/` and `.github/workflows/` directories into your repo
2. Make scripts executable: `chmod +x .github/workflows/scripts/*.sh`
3. Add `CLAUDE_CODE_OAUTH_TOKEN` to your repo's Actions secrets
4. Create the `auto-review` label: `gh label create auto-review --description "Automated codebase review" --color "0E8A16"`
5. Customize (see Configuration below)
6. Push to your default branch

## Configuration

### Remove Irrelevant Review Areas

Not every project needs all 12 areas. Remove what doesn't apply:

- **No payments?** Delete `e-commerce.md` and remove `e-commerce` from the workflow_dispatch options and `ALL_AREAS` in `resolve-review-area.sh`
- **No AI features?** Delete `ai-compliance.md` and remove it similarly
- **No user data?** May not need `privacy.md` or `compliance.md`

### Adjust the Schedule

Edit the cron in `codebase-review.yml`. Default is Sunday 06:00 UTC:

```yaml
schedule:
  - cron: '0 6 * * 0'  # Sunday 06:00 UTC
```

Change to any schedule you prefer. To stagger reviews across the week (2 per day), use multiple cron entries and update `resolve-review-area.sh` to map each cron slot to a specific area.

### CI Trigger Integration

The fix stage triggers your CI after pushing. Edit `trigger-ci-workflows.sh` to match your CI workflow filenames:

```bash
WORKFLOWS="${WORKFLOWS:-ci.yml checks.yml test.yml}"
```

### Slack Notifications

The `notify` job in `codebase-review.yml` prints a warning by default. To get Slack alerts on failure:

1. Add `SLACK_WEBHOOK_URL` to your repo secrets
2. Replace the notify step with:

```yaml
- name: Notify Slack on failure
  uses: slackapi/slack-github-action@v3.0.1
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK_URL }}
    webhook-type: incoming-webhook
    payload: |
      text: ":rotating_light: Codebase review workflow failed"
      blocks:
        - type: "header"
          text:
            type: "plain_text"
            text: ":rotating_light: Codebase Review Failed"
        - type: "section"
          fields:
            - type: "mrkdwn"
              text: "*Trigger:*\n${{ github.event_name }}"
            - type: "mrkdwn"
              text: "*Run:*\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View>"
```

### Using Your Own CLAUDE.md

If your project has a `CLAUDE.md` at the repo root, the review system will automatically read it and follow your project's coding standards. This is the best way to customize review behavior without editing the prompts.

## How It Works

### Codebase Review Pipeline

```
Sunday 06:00 UTC (or manual trigger)
        │
        ▼
┌─────────────────────────────────────┐
│  STAGE 1: REVIEW (30 min timeout)   │
│                                     │
│  For each review area (in parallel):│
│  1. Read CLAUDE.md + review prompt  │
│  2. Deep-dive audit of codebase     │
│  3. Create GitHub issue with        │
│     findings grouped by severity    │
│  4. Set MAXIMUM_FIX_PRIORITY        │
│  5. Close superseded issues         │
└─────────────────────────────────────┘
        │
        ▼ (if MEDIUM or HIGH)
┌─────────────────────────────────────┐
│  STAGE 2: FIX (90 min timeout)      │
│                                     │
│  1. Read review issue findings      │
│  2. Fix ALL findings (code changes) │
│  3. Run quality gates (lint/test)   │
│  4. Create branch + PR              │
│  5. Close superseded fix PRs        │
│  6. Trigger CI                      │
└─────────────────────────────────────┘
```

### PR Review Pipeline

```
PR opened / ready for review / /claude-review comment
        │
        ▼
┌─────────────────────────────────────┐
│  STAGE 1: REVIEW                    │
│  Post review comment with findings  │
│  Set MAXIMUM_FIX_PRIORITY           │
└─────────────────────────────────────┘
        │
        ▼ (if LOW, MEDIUM, or HIGH)
┌─────────────────────────────────────┐
│  STAGE 2: FIX                       │
│  Fix findings, push commits to PR   │
│  Monitor CI until green (3 retries) │
└─────────────────────────────────────┘
```

### Priority Levels

| Priority | Meaning | Auto-fix? |
|---|---|---|
| NONE | Clean, no issues | No |
| XLOW | Trivial nits | No |
| LOW | Minor issues | PR review: yes. Codebase review: no |
| MEDIUM | Real issues | Yes |
| HIGH | Critical issues | Yes |

## Adding Custom Review Areas

1. Create a new `.md` file in `.github/review-prompts/` with your checklist
2. Add the area name to `workflow_dispatch.inputs.review_area.options` in `codebase-review.yml`
3. Add it to `ALL_AREAS` in `resolve-review-area.sh`

Follow the existing prompt structure: Objective, Review Checklist with checkboxes, and Severity Guide.

## File Structure

```
.github/
├── review-prompts/
│   ├── security.md
│   ├── code-quality.md
│   ├── performance.md
│   ├── testing.md
│   ├── error-handling.md
│   ├── correctness.md
│   ├── privacy.md
│   ├── compliance.md
│   ├── ai-compliance.md
│   ├── documentation.md
│   ├── dependency-health.md
│   └── e-commerce.md
└── workflows/
    ├── codebase-review.yml      # Weekly deep-dive reviews
    ├── claude-pr-review.yml     # PR-level reviews
    └── scripts/
        ├── resolve-review-area.sh
        ├── extract-review-priority.sh
        ├── extract-pr-review-priority.sh
        └── trigger-ci-workflows.sh
```

## Cost Considerations

Each review area uses one Claude session (~30 min review + up to 90 min fix for the codebase-review pipeline, or up to 120 min fix for the PR-review pipeline which iterates on CI inline). Running all 12 areas weekly means up to 12 review sessions and potentially 12 fix sessions per week. To reduce costs:

- Remove review areas that don't apply to your project
- Adjust the schedule (biweekly instead of weekly)
- Use `--model sonnet` instead of `--model opus` in the workflow files for cheaper reviews (with some quality tradeoff)

## License

MIT
