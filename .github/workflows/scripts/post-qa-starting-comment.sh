#!/usr/bin/env bash
set -euo pipefail

# Post (or update) a short acknowledgment comment on a PR signalling that
# the AI QA Review workflow has started running. Without this, the user
# sees no feedback for 1-3 minutes — `track_progress` in claude-code-action
# only posts its tracking comment AFTER Node setup, Playwright install, and
# the wait-for-preview-url poll.
#
# Uses a dedicated marker `<!-- ai-qa-review-starting -->` distinct from
# the final report's `<!-- ai-qa-review -->` marker so the two can be
# managed independently. The post-comment step deletes this ack before
# (or while) posting the final report.
#
# Required env vars:
#   GH_TOKEN    - token with issues:write on REPO
#   REPO        - owner/repo of the PR's repository
#   PR_NUMBER   - PR number to comment on
#   RUN_ID      - github.run_id of the calling workflow run
#
# Optional env vars:
#   SERVER_URL  - github.server_url (default: https://github.com)

: "${GH_TOKEN:?}" "${REPO:?}" "${PR_NUMBER:?}" "${RUN_ID:?}"

SERVER_URL="${SERVER_URL:-https://github.com}"
MARKER='<!-- ai-qa-review-starting -->'
RUN_URL="${SERVER_URL}/${REPO}/actions/runs/${RUN_ID}"

BODY=$(cat <<EOF
${MARKER}

🤖 **AI QA Review starting** — waiting for the preview deploy, then I'll open it in a real browser to verify the change end-to-end. Full report with screenshots/video follows.

[Workflow run](${RUN_URL})
EOF
)

# Idempotent: if a previous run was cancelled before cleanup, adopt that
# comment instead of posting a duplicate.
EXISTING_ID=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
  | jq -r --arg marker "${MARKER}" \
      '[.[] | select(.body | contains($marker))] | first | (.id // empty)')

if [[ -n "${EXISTING_ID}" ]]; then
  echo "Updating existing starting-ack comment (id=${EXISTING_ID})"
  jq -n --arg b "${BODY}" '{body: $b}' \
    | gh api -X PATCH --input - "repos/${REPO}/issues/comments/${EXISTING_ID}" >/dev/null
else
  echo "Posting new starting-ack comment"
  jq -n --arg b "${BODY}" '{body: $b}' \
    | gh api -X POST --input - "repos/${REPO}/issues/${PR_NUMBER}/comments" >/dev/null
fi

echo "Done."
