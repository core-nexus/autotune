---
name: pr-merge-main
description: Merge origin's default branch into the current branch (or a PR branch), resolving conflicts thoughtfully
disable-model-invocation: true
argument-hint: '[PR-number-or-branch]'
---

Merge the latest default-branch tip (`origin/main`, `origin/master`, etc.) into a working branch. If a PR number or branch name is provided as `$ARGUMENTS`, use that. Otherwise, use the current branch.

## Steps

1. **Determine the default and target branches.**

   ```
   DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
   ```

   - If `$ARGUMENTS` is a PR number (digits only): look up the PR's head branch with `gh pr view <num> --json headRefName --jq .headRefName`.
   - If `$ARGUMENTS` is a branch name: use it directly.
   - If `$ARGUMENTS` is empty: use the current branch (`git branch --show-current`).
   - If the target branch equals `$DEFAULT_BRANCH`, stop and tell the user — merging the default branch into itself is a no-op.

2. **Decide: worktree or in-place.**
   - Run `git worktree list` to check if worktrees are supported and the repo is a full checkout (not already inside a worktree or a bare clone with no working tree).
   - **If worktrees are available and the current checkout is NOT already on the target branch**, create a temporary worktree for the merge so the user's working directory is undisturbed:
     ```
     git fetch origin "$DEFAULT_BRANCH"
     git fetch origin <target-branch>
     git worktree add /tmp/merge-main-<branch> <target-branch>
     cd /tmp/merge-main-<branch>
     ```
   - **Otherwise** (cloud environment, already on the target branch, or worktrees unavailable), work in-place:
     ```
     git fetch origin "$DEFAULT_BRANCH"
     git checkout <target-branch>   # if not already on it
     ```

3. **Perform the merge.**

   ```
   git merge "origin/$DEFAULT_BRANCH" --no-edit --no-verify
   ```

   `--no-verify` skips local pre-commit hooks (husky / lint-staged / etc.) on the merge commit. The files coming in from the default branch were already linted when they landed there, so re-running hooks on them only blocks the merge for issues that already exist on the default branch — not for anything this merge introduces.

4. **If there are conflicts**, resolve them thoughtfully:
   - For each conflicted file, read both sides and understand the intent of each change.
   - Keep the best parts of both branches — do not blindly accept one side.
   - Prefer the feature branch's new functionality combined with the default branch's latest fixes and refactors.
   - After resolving, stage the files and complete the merge commit.
   - The merge commit message should be: `Merge origin/<default-branch> into <branch>`.

5. **Push the result.**

   ```
   git push origin <target-branch>
   ```

   If push fails due to network errors, retry up to 4 times with exponential backoff (2s, 4s, 8s, 16s).

   **If push fails due to permissions** (not a network error — e.g. branch protection, insufficient access):
   - Create a new branch from the merged result: `git checkout -b <target-branch>-merge-main`
   - Push the new branch: `git push -u origin <target-branch>-merge-main`
   - Open a new pull request from the new branch, targeting the same base as the original PR.
   - In the new PR description, reference the original PR and note that this one supersedes it (e.g. "Supersedes #NNN — same changes with the default branch merged in").
   - Tell the user what happened and link both PRs.

6. **Clean up** (if a worktree was used):

   ```
   cd <original-directory>
   git worktree remove /tmp/merge-main-<branch>
   ```

7. **Report** what happened: which branch was updated, how many commits were merged, whether conflicts were resolved, and the final push status.
