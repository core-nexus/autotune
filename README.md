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

All reviews run simultaneously every **Sunday at 06:00 UTC**. You can also trigger any review manually via `workflow_dispatch`.

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

## Data Flow & Third-Party Processing

This system is itself an AI tool. Before installing it, you and your security
or compliance team should understand exactly what is sent to the third-party
model provider on each run.

**Recipient.** All inference calls are made to [Anthropic](https://www.anthropic.com/)
via the Claude Code action. Claude is a general-purpose AI assistant operated
by Anthropic; this repo does not host or run any model.

**What is transmitted on every run.** The Claude Code action gives the model
access to the GitHub Actions runner. In the course of running a review, the
model can and typically will read:

- the entire content of the repository at the checked-out commit, including
  any code, configuration, documentation, and test fixtures;
- the diff of every PR being reviewed (for the PR-review workflow);
- the title, body, and comments of related issues and PRs;
- CI workflow logs that the action chooses to fetch.

If a secret is accidentally committed (e.g. an `.env` file) it will be read
along with everything else. Keep your `.gitignore` and pre-commit hooks honest.

**Recommendations before installation.**

1. Read Anthropic's [data usage policy](https://www.anthropic.com/legal/privacy)
   and the [commercial terms](https://www.anthropic.com/legal/commercial-terms)
   for the Claude Code product to confirm whether your usage tier is excluded
   from training-data collection.
2. If you handle regulated data (PHI, PCI, regulated PII), get sign-off from
   your privacy/legal function and update your DPIA / vendor-risk register
   before enabling. The full repository content is in scope for what is
   transmitted.
3. Update your privacy notice and any internal data-flow diagrams to include
   "source code & repo metadata → Anthropic" if you ship product code through
   this system.
4. If your repository is private, double-check that `CLAUDE_CODE_OAUTH_TOKEN`
   is configured against an Anthropic account whose data-handling posture
   matches your requirements.

The system itself is risk-classified as **minimal / limited risk** under the
EU AI Act: it interacts only with developers, does not perform biometric
identification, profiling of natural persons, or any Annex III high-risk
use case. The transparency obligation that applies (Art. 50) is met by the
`claude[bot]` author identity on issues/PRs and by the AI-generation footer
appended to every issue, PR description, and review comment the system emits.

## Known Limitations

This system is an AI tool and inherits the limitations of the underlying
language model. Adopters should keep the following in mind:

- **No formal bias audit.** The reviewer has not been audited for bias on any
  particular dimension. Reviews of code for niche frameworks, less-common
  programming languages, or domain-specific DSLs may be less reliable than
  reviews of mainstream stacks well-represented in training data.
- **Training-distribution skew.** The reviewer will tend to recommend patterns
  common in its training data. If your codebase deliberately diverges from
  industry norms (custom build systems, unusual architectural choices, in-house
  abstractions), expect the reviewer to occasionally recommend changes that
  conflict with project conventions. A `CLAUDE.md` at the repo root mitigates
  this — the workflow reads and respects it.
- **Auto-closure of prior reviews can drop coverage.** Each weekly run closes
  the prior issue/PR for the same review area. The system attempts to record
  which prior findings are carried forward and which are not (see the auto-
  closure prompt in `codebase-review.yml`), but a model lapse could still cause
  a real finding from a prior run to be silently dropped. Treat any `Superseded
  by ...` comment as worth reviewing before closing-time.
- **Priority extraction may default to NONE on parse failure.** The fix stage
  only triggers when the priority is MEDIUM or HIGH. If the model emits a
  malformed `MAXIMUM_FIX_PRIORITY` line, the extractor scripts default to NONE
  and emit a `::warning::` annotation. Audit the workflow run summary if you
  expect findings but no fix PR appeared.
- **Stylistic-but-semantically-incorrect fixes.** The fix stage may produce
  diffs that read well and pass linters/tests but introduce subtle behavioural
  changes. This is the single biggest reason every auto-fix PR must be reviewed
  by a human under branch protection before merge — never enable auto-merge.
- **Cost is bounded by your Anthropic quota.** A misbehaving prompt or a model
  that decides to read large numbers of files can run up real spend. Set
  budgets/alerts on the Anthropic side.
- **Documentation freshness.** The review prompts in `.github/review-prompts/`
  cite specific articles, frameworks, and laws (e.g. EU AI Act Art. 50). These
  citations are the state of the law at the time the prompt was last updated;
  the reviewer is also instructed to do its own pre-review web search, but
  treat any legal citation surfaced in a review as a *pointer to verify*, not
  authoritative legal advice.

## Cost Considerations

Each review area uses one Claude session (~30 min review + up to 90 min fix). Running all 12 areas weekly means up to 12 review sessions and potentially 12 fix sessions per week. To reduce costs:

- Remove review areas that don't apply to your project
- Adjust the schedule (biweekly instead of weekly)
- Use `--model sonnet` instead of `--model opus` in the workflow files for cheaper reviews (with some quality tradeoff)

## License

MIT
