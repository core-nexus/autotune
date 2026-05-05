#!/usr/bin/env bash
set -euo pipefail

# Wait for a preview-deploy URL to appear on a PR.
#
# Strategy: poll the PR's issue comments for a URL matching
# PREVIEW_URL_PATTERN. Most preview-deploy bots (Vercel, Netlify,
# Cloudflare Pages, Render, etc.) post a URL in a PR comment within
# a minute of the PR opening — this script waits for that.
#
# Customize via env vars:
#   PREVIEW_URL_PATTERN    Extended-regex (POSIX ERE) matched against
#                          comment bodies. Defaults to a permissive
#                          HTTPS matcher; override for stricter matching.
#   PREVIEW_URL_MARKER     If set, only consider comments whose body
#                          contains this literal string (e.g. an HTML
#                          comment marker your deploy bot writes).
#   PREVIEW_URL_AUTHOR     If set, only consider comments by this user
#                          (e.g. "vercel[bot]").
#   MAX_ATTEMPTS           Number of poll attempts (default 60 = 20min
#                          at 20s interval).
#   SLEEP_SECS             Seconds between attempts (default 20).
#
# Writes to GITHUB_OUTPUT:
#   preview-url            The matched URL.
#   login-url              `${preview-url}/login` (commonly useful;
#                          ignore if your app uses a different path).
#
# Required env vars:
#   GH_TOKEN               Token with read access to PR comments.
#   REPO                   owner/repo
#   PR_NUMBER              The PR number to inspect.

: "${GH_TOKEN:?}"
: "${REPO:?}"
: "${PR_NUMBER:?}"
: "${GITHUB_OUTPUT:?}"

MAX_ATTEMPTS="${MAX_ATTEMPTS:-60}"
SLEEP_SECS="${SLEEP_SECS:-20}"
PREVIEW_URL_PATTERN="${PREVIEW_URL_PATTERN:-https://[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+}"
PREVIEW_URL_MARKER="${PREVIEW_URL_MARKER:-}"
PREVIEW_URL_AUTHOR="${PREVIEW_URL_AUTHOR:-}"

echo "Polling PR #${PR_NUMBER} in ${REPO} for preview URL"
echo "  pattern: ${PREVIEW_URL_PATTERN}"
[[ -n "${PREVIEW_URL_MARKER}" ]] && echo "  marker:  ${PREVIEW_URL_MARKER}"
[[ -n "${PREVIEW_URL_AUTHOR}" ]] && echo "  author:  ${PREVIEW_URL_AUTHOR}"
echo "  timeout: ~$((MAX_ATTEMPTS * SLEEP_SECS))s"

for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
  COMMENTS_JSON=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate 2>/dev/null || echo '[]')

  # Filter comments by optional marker + author, then concatenate matching
  # bodies, newest last (so a `tail -1` of matches picks the freshest).
  BODY=$(printf '%s' "${COMMENTS_JSON}" | MARKER="${PREVIEW_URL_MARKER}" AUTHOR="${PREVIEW_URL_AUTHOR}" python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
except Exception:
    data = []
marker = os.environ.get('MARKER') or ''
author = os.environ.get('AUTHOR') or ''
def keep(c):
    if not isinstance(c, dict):
        return False
    body = c.get('body') or ''
    if marker and marker not in body:
        return False
    if author and ((c.get('user') or {}).get('login') or '') != author:
        return False
    return True
matches = [c for c in data if keep(c)]
matches.sort(key=lambda c: c.get('updated_at') or c.get('created_at') or '')
for c in matches:
    print(c.get('body') or '')
")

  if [[ -n "${BODY}" ]]; then
    PREVIEW_URL=$(printf '%s' "${BODY}" | grep -oE "${PREVIEW_URL_PATTERN}" | tail -1 || true)

    if [[ -n "${PREVIEW_URL}" ]]; then
      # Trim a trailing slash for cleaner downstream URLs.
      PREVIEW_URL="${PREVIEW_URL%/}"
      echo "Found preview URL on attempt ${attempt}: ${PREVIEW_URL}"
      {
        echo "preview-url=${PREVIEW_URL}"
        echo "login-url=${PREVIEW_URL}/login"
      } >> "${GITHUB_OUTPUT}"
      exit 0
    fi
  fi

  echo "  attempt ${attempt}/${MAX_ATTEMPTS}: preview URL not yet available, sleeping ${SLEEP_SECS}s..."
  sleep "${SLEEP_SECS}"
done

echo "::error::Preview URL was not found on PR #${PR_NUMBER} within $((MAX_ATTEMPTS * SLEEP_SECS))s." \
     "Has your preview-deploy workflow posted a URL on the PR yet?"
exit 1
