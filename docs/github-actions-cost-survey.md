# GitHub Actions Usage & Cost Survey

_A survey of every way this repository uses GitHub Actions, written to find
places we can cut spend. Data pulled from the Actions API on 2026-07-24
(repo created 2026-04-05, so ~3.5 months of history)._

## TL;DR

- **This repo is _public_, so standard GitHub-hosted runner minutes are free.**
  The money we spend on "GitHub Actions" here is almost entirely **Claude Code
  plan credits** — every workflow invokes `anthropics/claude-code-action@v1`
  with `--model opus`, most of them with `--max-turns 250`. Runner-minute
  micro-optimizations save nothing on a public repo; **reducing the number and
  size of Opus agent runs is the only lever that saves real money.**
- **There is no "bundle size" job in this repository.** I searched every
  workflow, script, and file. The only mentions of "bundle size" are two
  checklist lines inside AI-review _prompts_ (`review-prompts/performance.md`
  and `claude-pr-review.yml`) that tell the reviewing agent to _flag large new
  dependencies_. Nothing measures, uploads, or tracks a bundle. See
  [The "bundle size" job](#the-bundle-size-job) below for what I think may have
  been meant and how the same intent maps onto what's actually here.
- The two per-PR reviewers (**Claude PR Review** and **AI QA Review**) are the
  recurring credit burn. The **Codebase Review** sweep is the single most
  expensive thing _when enabled_, but its weekly schedule is already commented
  out, so today it only runs on manual dispatch. **Sentry Triage** and **CI
  Auto-Fix** have never run.

## Cost model (read this first)

| Cost source | Applies here? | Notes |
|---|---|---|
| GitHub-hosted runner minutes | **No charge** | Public repo + `ubuntu-latest` (standard runner) = free minutes. |
| Larger/self-hosted runners | No | Every job uses `ubuntu-latest`. None configured. |
| Artifact storage | Negligible | Only QA Review uploads artifacts, 30-day retention, `if-no-files-found: ignore`. |
| **Claude Code plan credits** | **Yes — this is the spend** | Opus, mostly `--max-turns 250`. Cost per run scales with model × turns × context. |

So for the rest of this survey, "expensive" means **Opus credits consumed**,
and the knobs that matter are: _does it run at all_, _how often_, _how many
turns_, and _which model_.

## Inventory — all seven workflows

Lifetime run counts are from the Actions API. Many `issue_comment`-triggered
runs are **no-ops**: the job-level `if:` gate filters out comments that don't
contain the trigger phrase, so the run shows as "skipped" and spins up no
runner and no agent. The real credit cost lives in the non-skipped runs.

| Workflow | Trigger(s) | Lifetime runs | Model / turns | Per-run credit cost | Verdict |
|---|---|---|---|---|---|
| **Claude PR Review** (`claude-pr-review.yml`) | PR opened / ready-for-review; `/claude-review`, `/claude-fix` comments | **358** (≈60% skipped comment-gate no-ops in a recent sample) | Opus; review = _no turn cap_ (30-min timeout), fix = 250 | High — an Opus review on every PR, plus a second Opus fix pass when a finding is MEDIUM+ | Core value, but the biggest recurring burn. Trim. |
| **AI QA Review** (`ai-qa-review.yml`) | PR opened / ready-for-review; `/qa-review` comment | **59** | Opus; 250 turns | High — Opus 250-turn browser session per PR; also installs Chromium + spins **two** browser MCPs (Playwright _and_ Chrome DevTools), 45-min timeout | Heaviest per-run. Best cut candidate. |
| **Codebase Review** (`codebase-review.yml`) | `schedule` **(commented out)** + manual `workflow_dispatch` | **15** (all schedule, Apr 5–Jul 12, weekly; 10 ok / 5 failed) | Opus; review = no turn cap, fix = 250 | **Highest of all when enabled**: up to 15 areas × (review + fix), each Opus, fix up to 250 turns | Already throttled to manual-only. Keep it that way / subset it. |
| **Changelog** (`changelog.yml`) | `schedule` Mon+Thu 15:00 UTC; manual | **12** | Opus; **20 turns** | Low — capped at 20 turns, skips entirely when no PRs merged | Cheapest agent job. Recent runs look like they're failing — worth a look. |
| **@claude assistant** (`claude.yml`) | `@claude` mention in issue/PR/review | **49** (29/30 sampled were skipped) | Opus; 250 turns | Spiky — only when a maintainer actually summons it; almost all runs are gate no-ops | On-demand and mostly free. Keep. |
| **Sentry Triage** (`sentry-triage.yml`) | `repository_dispatch` from a Sentry webhook bridge; manual | **0** — never fired | Opus; 250 turns + Sentry MCP | None today; Opus-250 per alert once the Worker bridge is live | Dormant. Watch alert volume if you turn it on. |
| **CI Auto-Fix** (`claude-auto-fix-ci.yml`) | `workflow_run` on a CI workflow completing | **0** — ships disabled | Opus; 250 turns | None today; gated behind `ENABLE_AUTO_FIX_CI=true` | Dormant. No action. |

Total lifetime workflow runs across the repo: **635**.

## Where the money actually goes

Ranked by real, recurring credit spend today:

1. **Claude PR Review — the volume leader.** Runs an Opus review on _every_ PR
   at open/ready, and the review stage has **no `--max-turns` cap** (bounded
   only by the 30-minute timeout). When a finding is rated MEDIUM or higher it
   chains a **second** Opus pass (the fixer, `--max-turns 250`) that edits code
   and babysits CI. Two Opus agents per qualifying PR.
2. **AI QA Review — the heaviest single run.** Opus `--max-turns 250` driving a
   real browser on every PR, plus Chromium install and **two** MCP servers
   (Playwright + Chrome DevTools). On a public repo the runner minutes are
   free, but the 250-turn Opus browser session is not.
3. **Codebase Review — the big one, currently sleeping.** If the weekly cron is
   uncommented with `all` areas, that's ~15 Opus reviews **plus** ~15 Opus
   fixers (each up to 250 turns) every Sunday. This is by far the largest
   potential line item; it's already been defused to manual-only.

Everything else (@claude, Changelog, Sentry, Auto-Fix) is either on-demand,
turn-capped, or dormant, and is not where the spend is.

## The "bundle size" job

**It doesn't exist in this repo.** Concretely, I checked:

- All 7 files in `.github/workflows/` — no build, no bundler, no size step.
- Every script in `.github/workflows/scripts/` — none measure a bundle.
- A full-repo search for `bundlesize` / `size-limit` / `bundlewatch` /
  `analyze bundle` / `source-map-explorer` — no tool, no config, no job.
- There's no application to bundle here: the only `package.json` is the
  Cloudflare Worker in `workers/sentry-triage/`, which has no size CI.

The only "bundle size" strings are **instructions to the AI reviewer**, not a
measurement job:

- `.github/workflows/claude-pr-review.yml` — _"Bundle size: flag large new
  dependencies."_
- `.github/review-prompts/performance.md` / `dependency-health.md` — checklist
  items asking the reviewer to watch bundle impact.

So there's no job to move to "weekly on main," and — because the repo is public
— even if there were, its runner minutes would be free. **If you're thinking of
a bundle-size check in a _different_ (private) repo, point me at it and I'll
make that change there.** Within _this_ repo, the faithful version of your
request — "an expensive periodic job we don't really track over time; run it
rarely, on main only" — already describes **Codebase Review**, and it's already
been switched off the schedule. The recommendations below carry that same
spirit to the jobs that _are_ spending today.

## Recommendations (prioritized by savings, cheapest-risk first)

Each is a knob, not a done change — I've left the workflows untouched pending
your call on which to pull. Rough savings are relative to _current_ credit
spend.

1. **Switch the review/QA stages from Opus to Sonnet.** Single biggest lever.
   `--model sonnet` on `claude-pr-review.yml` (review stage) and
   `ai-qa-review.yml` cuts per-run credit cost roughly **3–5×** at some quality
   tradeoff. Keep Opus for the fixer stages if you want depth where it edits
   code. _Est: large, low effort._
2. **Cap the turn count on the review stages.** The PR-review _review_ stage
   and the Codebase-review _review_ stage have no `--max-turns`. Adding e.g.
   `--max-turns 40` bounds worst-case spend with little quality loss (review is
   read-only). _Est: medium, trivial._
3. **Make AI QA Review opt-in instead of automatic.** It's the heaviest run and
   the least universally useful (most PRs have nothing browser-observable).
   Options: drop the auto `pull_request` trigger and keep only `/qa-review`; or
   gate it behind a `qa` label; or restrict `paths` to UI directories. Also
   consider dropping the **Chrome DevTools MCP** (Playwright alone covers the
   automation) and lowering `--max-turns`. _Est: large, low effort._
4. **Reduce PR-review frequency.** If a review on every single PR is more than
   you need, gate the auto trigger behind a label or make it `/claude-review`
   opt-in, and lean on the `MAXIMUM_FIX_PRIORITY` threshold (already MEDIUM) so
   the second Opus fixer pass fires less often. _Est: medium, low effort._
5. **Keep Codebase Review manual — or schedule a _subset_.** If you do want it
   on a cron, don't run `all` 15 areas weekly. Run the 3–4 areas you actually
   act on (e.g. security, correctness), monthly, on main. _Est: prevents the
   largest potential bill._
6. **Fix or slow the Changelog job.** Its recent runs appear to be failing —
   paying (in the scheduled agent run) to produce nothing. Worth a diagnosis;
   and Mon+Thu could drop to weekly. _Est: small, but it's failing spend._
7. **Leave @claude, Sentry Triage, and CI Auto-Fix as-is.** On-demand or
   dormant; not where the money is.

## Appendix — how to verify

- Run history: `mcp__github__actions_list` → `list_workflow_runs` per workflow
  file (`resource_id: <file>.yml`); the `total_count` field is the lifetime
  count.
- Public/free confirmation: repo `private: false` via
  `search_repositories repo:core-nexus/claude-prod`.
- "No bundle job": `grep -ri 'bundlesize\|size-limit\|bundlewatch' .` returns
  only prose in review prompts.
