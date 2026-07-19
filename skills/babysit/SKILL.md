---
name: babysit
description: Babysit open PRs — resolve merge conflicts, retrigger stuck CI, and nudge the AI review/fix/QA pipeline forward
allowed-tools: Bash(gh *),Bash(git *),Agent
argument-hint: '[--dry-run]'
---

Scan all open PRs you can act on and take one automated action per PR based on their state. Designed to run inside a `/loop` — each invocation processes every PR that needs attention and exits; the next iteration catches follow-up work.

This skill assumes the repo has the [claude-code-review](https://github.com/core-nexus/claude-code-review) workflows installed (or equivalents that respond to `/claude-review`, `/claude-fix`, and optionally `/qa-review`). If your repo doesn't have a workflow for one of these slash commands, the corresponding priority is harmless — the comment is posted and nothing happens.

**🧹 Every invocation is a fresh start.** Re-derive every PR's state from fresh `gh` output. Don't reuse classifications, don't assume prior actions landed, and don't trust rules remembered from earlier in the session — treat THIS SKILL.md as the only source of truth. The only durable state between runs is the lock file and on-GitHub state.

**One action per PR, all PRs in parallel.** Git work (update-branch, empty commit) runs in isolated worktrees; review/fix dispatches comment `/claude-review`, `/claude-fix`, or `/qa-review` on the PR. Nothing conflicts, so nothing defers.

**Dry-run:** if `$ARGUMENTS` contains `--dry-run`, report what each PR needs but don't push, merge, or comment.

## Step 0 — Acquire lock

Only one instance may run at a time. Use `/tmp/babysit.lock`:

- **Exists and less than 2 hours old** — another instance is running. Print `Another babysit instance is already running (lock acquired at <ts>). Exiting.` and STOP.
- **Otherwise** — delete if stale, then `date +%s > /tmp/babysit.lock`.
- **On exit (success or error)** — `rm -f /tmp/babysit.lock`.

## Step 1 — Gather PR data

```
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
ME="$(gh api user --jq .login)"
gh pr list --state open --search 'sort:updated-desc' --limit 100 \
  --json number,title,headRefName,mergeable,mergeStateStatus,statusCheckRollup,author,isDraft > /tmp/prs-recent.json
```

One query + local filter guarantees we see the most recently-touched PRs across both "me" and "bots" without two queries racing each other's `--limit` cutoffs. We babysit our own PRs always, and bot PRs as well (so reviews fire on Dependabot/Sentry/etc. without manual nudging). Using `author.is_bot` (rather than a hardcoded list) auto-picks-up new bots.

```
jq --arg me "$ME" '[.[] | select(.isDraft == false) | select(.author.login == $me or .author.is_bot == true)] | .[:25]' /tmp/prs-recent.json
```

Drafts are always skipped. If the filtered set is empty, report `No open non-draft PRs found — nothing to do.` and STOP.

> If multiple humans run this skill against the same repo, they'll race on bot PRs. The actions are idempotent (the loop caps in Step 2a stop runaway comments), but it's noisy. If that's an issue, restrict bot handling to a single allowlisted user via a local edit.

## Step 2 — Early exit per PR

Before deeper inspection, mark a PR "skip" if it matches either row:

| Condition                                                                                                          | Report as                  |
| ------------------------------------------------------------------------------------------------------------------ | -------------------------- |
| NOT bot-authored AND all checks `SUCCESS` AND `mergeable != "CONFLICTING"` AND `reviewNeedsFix == false` (Step 2a) | "Healthy — skipped"        |
| ANY check is `IN_PROGRESS` or `QUEUED`                                                                             | "CI in progress — skipped" |

**Don't touch healthy BLOCKED PRs.** `mergeStateStatus == "BLOCKED"` with all-green checks just means branch protection is waiting for the author to click "Update branch" — that's not our job. Bot PRs with green checks still flow to Priority 2 (review), but must wait for CI to finish like everyone else. A PR with green CI but a pending MEDIUM/HIGH review finding is NOT healthy — see Step 2a.

If every PR was skipped, report the summary and STOP.

For PRs that survive early exit, also fetch the last commit author:

```
gh api repos/${REPO}/commits/{head_sha} --jq '.author.login'
```

### Step 2a — Review state and loop caps

A review comment ending in `MAXIMUM_FIX_PRIORITY: MEDIUM` / `HIGH` is unfinished work — even with green CI — until a `/claude-fix` has been posted in response. MEDIUM is the threshold because the fix workflow itself treats MEDIUM and above as in-scope; LOW is left for human follow-up. If the repo runs review and QA in parallel and fix should wait on BOTH, only trigger `/claude-fix` once QA has also posted — otherwise fix kicks off before QA evidence is available. (If the repo doesn't run QA at all, set `QA_ENABLED=false` below; the QA gates are skipped.)

Also compute loop-safety counters so we don't post `/claude-fix` or `/claude-review` endlessly when nothing is changing (e.g. a self-referential workflow-file PR where the review check fails for a reason no fix can clear until merge).

```
gh api "repos/${REPO}/issues/{PR#}/comments" --jq '[.[] | {created_at, user: .user.login, body}]' > /tmp/comments-{PR#}.json
HEAD_AT="$(gh api repos/${REPO}/pulls/{PR#}/commits --jq '.[-1].commit.committer.date')"
```

**Telling a review-finding comment apart from a `/claude-fix` response.** Both are authored by `claude[bot]` (both post via `anthropics/claude-code-action`), and both echo `MAXIMUM_FIX_PRIORITY:<level>` — the review states findings at that level; the fix-response echoes the threshold it worked against. Their `**Claude finished @<user>'s task**` headers do **not** separate them either: the review fires on `pull_request`, so its header names the *human PR author* (`github.actor`) — exactly like a human-typed `/claude-fix` response. The reliable signal is **position relative to the `/claude-fix` command**:

- A **`/claude-fix` response** is a `claude[bot]` `MAXIMUM_FIX_PRIORITY:` comment whose nearest *preceding* trigger comment (a standalone `/claude-review` or `/claude-fix` on its own line) is `/claude-fix`.
- A **review-finding** is a `claude[bot]` `MAXIMUM_FIX_PRIORITY:` comment that is NOT preceded by a `/claude-fix` — it responds either to the PR opening (auto-review) or to a `/claude-review`.

Matching on `MAXIMUM_FIX_PRIORITY:` alone (without this classification) treats a fix-response as a fresh finding, flips `reviewNeedsFix` true forever, and burns `/claude-fix` retries on already-addressed PRs. (Do NOT try to distinguish them by the `@<user>` in the header — the review names the human PR author, not `claude[bot]`.)

To classify: walk the PR's comments in chronological order tracking the most recent trigger command seen (`/claude-review` or `/claude-fix`); tag each `claude[bot]`-authored `MAXIMUM_FIX_PRIORITY:` comment as a review-finding or a fix-response per the rule above.

From `comments-{PR#}.json` and `HEAD_AT`, derive:

1. `reviewNeedsFix` — find the newest **review-finding** comment (classified as above; author `claude[bot]`). If its `MAXIMUM_FIX_PRIORITY` value is `NONE` / `XLOW` / `LOW` (or no review-finding exists), `reviewNeedsFix = false`. If `QA_ENABLED=true`, also require a comment containing `<!-- ai-qa-review -->` to exist — if QA hasn't posted yet, `reviewNeedsFix = false` (wait for QA). Otherwise, look for a `/claude-fix` command comment posted AFTER that review-finding. If present, `reviewNeedsFix = false` (already dispatched). Else, `reviewNeedsFix = true`.
2. `reviewMissing` — `true` if NO **review-finding** comment exists on the PR (a review has never posted findings). A `/claude-fix` response that echoes `MAXIMUM_FIX_PRIORITY:` does NOT count. Else `false`.
3. `fixAttemptsOnHead` — count of comments with `created_at >= HEAD_AT` whose body contains `/claude-fix` as a standalone slash command on its own line.
4. `reviewAttemptsOnHead` — same, but for `/claude-review`.

Idempotent by construction: once `/claude-fix` is posted for a given review-finding `MAXIMUM_FIX_PRIORITY:` comment, subsequent runs see it and stop posting — until a newer review-finding appears.

Loop safety: `/claude-fix` and `/claude-review` are each capped at **3 posts per head commit**. A new push resets both counters. This bounds the retry loop when the underlying failure can't be cleared by re-invocation (and is cheap to un-cap by pushing any commit, including an empty one).

### Step 2b — QA review pending (`qaNeeded`)

Only relevant if `QA_ENABLED=true` (the repo has a `/qa-review` workflow such as `ai-qa-review.yml`).

The review pipeline runs review and QA IN PARALLEL on PR open, then the fix job runs once both finish: **(review ∥ QA) → fix (if needed)**. QA is usually triggered automatically by `pull_request`, but that event can be missed (cross-fork PRs, PRs opened as draft then converted to ready later on a runner that hiccups). This priority is the belt-and-suspenders: when a PR is old enough that QA should have fired but no QA comment exists, post `/qa-review` to kick it off.

Using the same `/tmp/comments-{PR#}.json` from Step 2a:

1. The PR is old enough that QA should have reached the browser phase. The QA workflow blocks waiting for the preview URL before it can click anything; nudging `/qa-review` before that finishes just cancels and replaces the QA run that's already waiting. Require: PR is older than 15 minutes (gives the preview-deploy + QA's first turn a comfortable window).

   If the repo posts a stable preview-deploy marker comment (e.g. `<!-- preview-deploy-comment -->` from a Cloudflare Pages or Netlify bot), additionally require a comment whose body contains that marker — set `PREVIEW_MARKER` below if so. If not configured, the 15-minute age check stands alone.

   If the age condition is unmet (or the marker is required but absent), `qaNeeded = false`.

2. QA has NOT already run for this cycle:
   - If no comment contains the marker `<!-- ai-qa-review -->` AND no comment contains `/qa-review`, `qaNeeded = true`.
   - Otherwise `qaNeeded = false` (already ran or already dispatched — wait for the QA comment to appear).

Idempotent by construction, same pattern as `reviewNeedsFix`: once `/qa-review` is posted OR the `<!-- ai-qa-review -->` comment appears, subsequent runs see it and stop posting.

### Configuration (edit per repo if needed)

```
QA_ENABLED=true             # set to false if the repo has no /qa-review workflow
PREVIEW_MARKER=""           # e.g. "<!-- preview-deploy-comment -->" — empty disables marker check
```

## Step 3 — Classify remaining PRs

Walk in priority order. **First match wins**; do not apply multiple actions to the same PR.

Shorthand used below:

- `behind` — `gh api repos/${REPO}/compare/main...{headRefName} --jq '.behind_by'` is `> 0` (main has new commits). Replace `main` with the repo's default branch if different (`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`).
- `stuckCI` — any check has `conclusion` in `FAILURE` / `CANCELLED` / `TIMED_OUT`.
- `checksPending` — checks list is empty or all-pending.
- `botLastCommit` — last commit author is a bot.
- `reviewCheckFailed` — the `Claude PR Review` entry in `statusCheckRollup` has `conclusion` in `FAILURE` / `CANCELLED` / `TIMED_OUT`.
- `qaHasPosted` — some comment on the PR contains the `<!-- ai-qa-review -->` marker. (If `QA_ENABLED=false`, treat as `true` so P7 doesn't gate on it.)

| Priority | Condition                                                                            | Action                                                           |
| -------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------- |
| 1        | `mergeable == "CONFLICTING"`                                                         | Update branch (merge default branch in worktree)                 |
| 2        | Bot-authored PR needing review (see below)                                           | Update branch, then comment `/claude-review`                     |
| 3        | `checksPending && botLastCommit && behind`                                           | Update branch (merge retriggers CI)                              |
| 4        | `checksPending && botLastCommit`                                                     | Empty commit `"ci: retrigger checks"`                            |
| 5        | `stuckCI && behind`                                                                  | Update branch (same as clicking GitHub "Update branch")          |
| 6        | `reviewMissing && reviewCheckFailed && reviewAttemptsOnHead < 3`                     | Comment `/claude-review`                                         |
| 7        | `(FAILURE conclusion OR (reviewNeedsFix AND qaHasPosted)) && fixAttemptsOnHead < 3`¹ | Comment `/claude-fix`                                            |
| 8        | `CANCELLED` / `TIMED_OUT` conclusion `&& botLastCommit`                              | Empty commit `"ci: retrigger checks"`                            |
| 9        | `qaNeeded` (see Step 2b; only if `QA_ENABLED=true`)                                  | Comment `/qa-review`                                             |

¹ The `reviewNeedsFix && qaHasPosted` gate is the parallel-pipeline invariant: fix is supposed to run against _both_ review and QA findings, so we wait for QA's `<!-- ai-qa-review -->` comment before nudging `/claude-fix`. The `FAILURE conclusion` half bypasses this — red CI is urgent and blocks merge regardless of QA's state.

### Why this ordering

- **P5 before P7 for red CI.** A red check on a stale branch is ambiguous — the fix may already be on main (test fixtures, dep bumps, CI workflow changes). Updating the branch is the human equivalent of clicking "Update branch"; if CI is still red on the next loop, P7 fires `/claude-fix`. Avoids wasting `/claude-fix` runs on stale-branch artifacts.
- **P6 before P7 so we run the review before trying to fix nothing.** When the `Claude PR Review` check is red AND no `MAXIMUM_FIX_PRIORITY:` comment has ever been posted, the auto-triggered review never actually produced findings — `/claude-fix` has no review-side work to do. Re-invoking `/claude-review` is the right remedy. If the review fails for a reason that can't be cleared in-PR (classically: a PR that edits the review workflow itself, where GitHub's workflow-identity check rejects the app-token exchange), the 3-attempt cap stops the loop.
- **Review-driven fixes bypass P5.** P7 still fires on `reviewNeedsFix` even when behind main — `/claude-fix` can cope with a stale branch on its own, and leaving an in-scope MEDIUM/HIGH review finding parked would silently drop work.
- **P7 gates on QA completion.** Because fix is supposed to run after BOTH review and QA, `reviewNeedsFix` waits for the `<!-- ai-qa-review -->` marker before firing `/claude-fix`. If QA is missing, P9 handles it first on this run; P7 fires next iteration once QA has posted.
- **Why cap P6/P7 at 3.** Empirically, when three consecutive `/claude-fix` (or `/claude-review`) runs against the same head commit produce the same "nothing to do" result, the next one will too. Three attempts is generous enough to ride through transient CI flakes and slow queues, tight enough to keep the PR timeline readable. The counter is scoped to the current head commit, so any real push (including a one-line empty commit) resets to zero.
- **P8 requires `botLastCommit`.** A human's last push already triggered CI; if something was cancelled, that may be intentional. P3/P4 use the same gate for the same reason.
- **P9 can fire without waiting for review/fix.** QA runs in parallel with review, so its belt-and-suspenders nudge doesn't need any sequencing — just "no QA comment exists on a PR old enough to have kicked off".
- **Never rebase green BLOCKED PRs.** P5 requires red CI _AND_ behind — not just behind. "BLOCKED + green" is a human merge-time concern, not ours; pre-emptively rebasing would thrash CI across many healthy PRs.

### Priority 2 — Bot PR needing review

Fire only if ALL of:

1. `author.is_bot == true`.
2. Author is NOT on the skip allowlist (below).
3. PR is older than 1 minute (let CI register).
4. No check is `IN_PROGRESS` or `QUEUED` (let CI finish).
5. No existing comment contains `MAXIMUM_FIX_PRIORITY:` (idempotency — already reviewed).
6. Changes are substantive — more than docs-only (`.md`), comment-only tweaks, pure dep bumps (`package.json` / `yarn.lock` / `Cargo.lock` / etc.), or config-only tweaks (`.json` / `.yaml` / `.yml`, no code).

Update the branch first (so the review sees latest code), then comment `/claude-review`.

**Skip allowlist** — match the bare bot name case-insensitively (logins may come prefixed, e.g. `app/dependabot`, `dependabot[bot]`):

- `dependabot` — dependency bumps, purely mechanical.

Default to reviewing any other bot. A false negative (skipping a bot that should have been reviewed) is worse than a false positive (reviewing a trivial PR). Add to the allowlist only if a bot is reliably always-mechanical.

## Step 4 — Execute all actions in parallel

All actions are independent: git work runs in isolated worktrees, comments are direct `gh` calls. Launch everything at once.

### Never switch the user's branch

**NEVER `git checkout <branch>` in the main working tree.** All git work happens in worktrees under `/tmp/`.

### Worktree helper

Worktree reuse is expected — if `/tmp/babysit-<branch>` exists from a prior run, reuse it; don't abort and don't pick a unique path.

```
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
SAFE_BRANCH="$(echo '<branch>' | tr '/' '-')"
WORKTREE="/tmp/babysit-${SAFE_BRANCH}"
git fetch origin <branch> "$DEFAULT_BRANCH"
if [ -d "$WORKTREE" ]; then
  cd "$WORKTREE"
  git reset --hard HEAD && git clean -fd
  git checkout <branch>
  git reset --hard "origin/<branch>"
else
  git worktree add "$WORKTREE" <branch>
  cd "$WORKTREE"
fi
# ... do work ...
cd -
git worktree remove "$WORKTREE" || true   # safe to leave; next run will reuse
```

### Actions

- **Update branch** (P1, P3, P5, and the merge step of P2) — in the worktree:
  ```
  git merge "origin/${DEFAULT_BRANCH}" --no-edit
  git push origin <branch>
  ```
  If the merge has conflicts you can't resolve mechanically, abort (`git merge --abort`) and surface the PR in the report with status `CONFLICT (manual)` — leave it for a human.

  > Alternative: `gh pr update-branch <PR#>` is the GitHub-native equivalent and avoids the worktree entirely. Prefer it when available; fall back to the worktree merge above if the API rejects it (e.g. branch protection requires up-to-date checks first).

- **Empty commit** (P4, P8) — use the worktree helper above, then:
  ```
  git commit --allow-empty -m "ci: retrigger checks"
  git push origin <branch>
  ```

- **PR comment** (P2, P6, P7, P9) — no worktree needed:
  ```
  gh pr comment <PR#> --body '/claude-review'   # P2 after the merge completes; P6 to retrigger a review that never posted findings
  gh pr comment <PR#> --body '/claude-fix'      # P7 — handles red CI AND MEDIUM/HIGH review findings together
  gh pr comment <PR#> --body '/qa-review'       # P9 — kicks off the visual/behavioural QA workflow
  ```

## Step 5 — Report

Print the raw `date` output at the top, then a summary table. Include PRs that got an action, plus any PR whose P6/P7 retry cap was hit on the current head commit (Action `—`, so the user can see we deliberately stopped). Skip fully healthy PRs. Sort by Status (alphabetical), then PR number (ascending).

**PR numbers MUST be clickable links** — use `gh pr view {PR#} --json url --jq .url` and format as `[{PR#}](url)`. No placeholder URLs.

```
Mon Apr  7 19:16:42 PDT 2026

| PR | Title | Status | Action |
|----|-------|--------|--------|
| [42](https://github.com/owner/repo/pull/42) | fix: off-by-one in pagination | CONFLICTING | updated branch |
| [51](https://github.com/owner/repo/pull/51) | feat: add CSV export | CHECK FAIL | commented /claude-fix |
| [58](https://github.com/owner/repo/pull/58) | chore: upgrade Vite | REVIEW MEDIUM | commented /claude-fix |
| [60](https://github.com/owner/repo/pull/60) | ci: review tracking cleanup | FIX CAP (3/3) | — |
| [63](https://github.com/owner/repo/pull/63) | refactor: split auth module | NEEDS REVIEW | commented /claude-review |
| [65](https://github.com/owner/repo/pull/65) | fix: race in webhook handler | CANCELLED + behind main | updated branch |
| [70](https://github.com/owner/repo/pull/70) | feat: invoice PDF rendering | QA PENDING | commented /qa-review |
```

Use `FIX CAP (n/3)` when `fixAttemptsOnHead >= 3` and `/claude-fix` would otherwise fire, and `REVIEW CAP (n/3)` for the `/claude-review` equivalent.

If all PRs were healthy, report `All PRs are clean — nothing to do.`
