#!/usr/bin/env bash
set -euo pipefail

# Post the QA review report as a PR comment. Replaces the more elaborate
# external-artifact-repo publish flow some projects use; this version
# uses GitHub Actions artifacts only and links to them from the comment.
#
# Behavior:
#   - Reads the agent's draft from $ARTIFACTS_DIR/_comment.md.
#   - Replaces relative `./qa-artifacts/<file>` references with the
#     artifact-bundle download URL (since GitHub PR comments can't
#     render images from a runner filesystem path).
#   - If $MEDIA_BASE_URL is set, rewrites those refs to
#     `${MEDIA_BASE_URL}/<file>` instead — useful when you've mirrored
#     the captured media to a public host (e.g. another GitHub repo,
#     S3, your CDN) and want inline image rendering. Set it in a step
#     that runs BEFORE this one.
#   - Deletes the starting-ack comment posted by post-qa-starting-comment.sh.
#   - Posts the body as a new PR comment carrying `<!-- ai-qa-review -->`.
#   - Falls back to a generic message if _comment.md is missing/empty.
#
# Required env vars:
#   GH_TOKEN        - token with issues:write on REPO
#   REPO            - owner/repo
#   PR_NUMBER       - PR number
#   RUN_ID          - github.run_id of the calling workflow run
#   ARTIFACTS_DIR   - directory containing _comment.md and media
#   ARTIFACT_NAME   - name of the workflow artifact bundle to link to
#
# Optional env vars:
#   SERVER_URL      - github.server_url (default: https://github.com)
#   QA_RESULT       - job.status of the qa step (success|failure|cancelled)
#   MEDIA_BASE_URL  - if set, rewrite ./qa-artifacts/<f> → $MEDIA_BASE_URL/<f>

: "${GH_TOKEN:?}" "${REPO:?}" "${PR_NUMBER:?}" "${RUN_ID:?}" "${ARTIFACTS_DIR:?}" "${ARTIFACT_NAME:?}"

SERVER_URL="${SERVER_URL:-https://github.com}"
QA_RESULT="${QA_RESULT:-success}"
MEDIA_BASE_URL="${MEDIA_BASE_URL:-}"

RUN_URL="${SERVER_URL}/${REPO}/actions/runs/${RUN_ID}"
ARTIFACT_URL="${RUN_URL}#artifacts"
COMMENT_FILE="${ARTIFACTS_DIR}/_comment.md"
STARTING_MARKER='<!-- ai-qa-review-starting -->'
REPORT_MARKER='<!-- ai-qa-review -->'

# Always try to delete the starting-ack comment so we don't leave it
# hanging next to the final report.
delete_starting_ack() {
  local ids
  ids=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
    | jq -r --arg marker "${STARTING_MARKER}" \
        '.[] | select(.body | contains($marker)) | .id')
  if [[ -z "${ids}" ]]; then
    return
  fi
  while read -r id; do
    [[ -z "${id}" ]] && continue
    echo "Deleting starting-ack comment (id=${id})"
    gh api -X DELETE "repos/${REPO}/issues/comments/${id}" >/dev/null \
      || echo "::warning::Failed to delete starting-ack comment id=${id}"
  done <<<"${ids}"
}

# Build the comment body. Three paths:
#   1. _comment.md exists and has content → use it (with link rewrites).
#   2. _comment.md missing/empty AND qa job failed → generic failure msg.
#   3. _comment.md missing AND qa job succeeded → generic "no report" msg.
build_body() {
  if [[ -s "${COMMENT_FILE}" ]]; then
    local body
    body=$(cat "${COMMENT_FILE}")

    # Rewrite ./qa-artifacts/<file> references.
    if [[ -n "${MEDIA_BASE_URL}" ]]; then
      body=$(printf '%s' "${body}" \
        | sed -E "s#\\./qa-artifacts/([^[:space:])\"<>]+)#${MEDIA_BASE_URL%/}/\\1#g")
    else
      # No public host configured — replace inline image syntax with a
      # link to the artifact bundle so the reference at least resolves
      # to something useful, and add a header note pointing to the bundle.
      body=$(printf '%s' "${body}" \
        | sed -E "s#!\\[([^]]*)\\]\\(\\./qa-artifacts/([^)]+)\\)#[\\1 (\`\\2\` — download from artifact bundle)](${ARTIFACT_URL})#g" \
        | sed -E "s#\\./qa-artifacts/([^[:space:])\"<>]+)#${ARTIFACT_URL}#g")

      # Prepend a media-availability note right after the opening marker.
      local note=$'> 📦 Screenshot/video evidence for this run is bundled as a workflow artifact: ['"${ARTIFACT_NAME}"']('"${ARTIFACT_URL}"$')\n>\n> To inline screenshots in PR comments, set `MEDIA_BASE_URL` in the post-comment step to a public host where you mirror the captured media.\n\n'
      # Insert the note right after the marker line if present, else prepend.
      if grep -qF "${REPORT_MARKER}" <<<"${body}"; then
        body=$(awk -v m="${REPORT_MARKER}" -v n="${note}" '
          { print }
          $0 ~ m && !done { print ""; printf "%s", n; done=1 }
        ' <<<"${body}")
      else
        body="${REPORT_MARKER}"$'\n\n'"${note}${body}"
      fi
    fi

    printf '%s\n' "${body}"
    return
  fi

  # No draft from the agent. Build a fallback.
  cat <<EOF
${REPORT_MARKER}

## 🤖 AI QA Review — no report produced

The QA agent did not write a report (\`_comment.md\` missing or empty). This usually means the agent crashed before its final write step, or the workflow was cancelled mid-run.

- **Job status:** \`${QA_RESULT}\`
- [Workflow run](${RUN_URL})
- [Artifact bundle](${ARTIFACT_URL}) (may be empty)

If this is happening repeatedly, check the workflow logs and the QA pre-warm step in particular.

AI_QA_BLOCKING:NO
AI_QA_MAX_PRIORITY:NONE
EOF
}

delete_starting_ack

BODY=$(build_body)

echo "Posting QA review comment to PR #${PR_NUMBER}"
jq -n --arg b "${BODY}" '{body: $b}' \
  | gh api -X POST --input - "repos/${REPO}/issues/${PR_NUMBER}/comments" >/dev/null

echo "Done."
