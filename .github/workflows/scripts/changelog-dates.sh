#!/usr/bin/env bash
set -euo pipefail

# Determine the "since" date for changelog updates.
# Finds the most recent dated heading in the changelog file. When the changelog
# has no dated entries yet (or does not exist), falls back to a lookback window.
#
# Required env vars:
#   GITHUB_OUTPUT
# Optional env vars:
#   CHANGELOG_FILE          - path to the changelog (default: CHANGELOG.md)
#   CHANGELOG_LOOKBACK_DAYS - fallback window in days when no date is found (default: 14)

: "${GITHUB_OUTPUT:?}"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
CHANGELOG_LOOKBACK_DAYS="${CHANGELOG_LOOKBACK_DAYS:-14}"

LAST_DATE=""
if [[ -f "${CHANGELOG_FILE}" ]]; then
  # Match the first YYYY-MM-DD found in a Markdown heading line (e.g.
  # "## 2025-01-15" or Keep-a-Changelog's "## [1.2.0] - 2025-01-15").
  LAST_DATE=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "${CHANGELOG_FILE}" | head -1 || true)
fi

if [[ -z "${LAST_DATE}" ]]; then
  # GNU date (Linux/CI runners) first, then BSD/macOS date for local testing.
  LAST_DATE=$(date -u -d "${CHANGELOG_LOOKBACK_DAYS} days ago" +%Y-%m-%d 2>/dev/null \
    || date -u -v-"${CHANGELOG_LOOKBACK_DAYS}"d +%Y-%m-%d)
fi

echo "last_date=${LAST_DATE}" >> "${GITHUB_OUTPUT}"
echo "Last changelog date: ${LAST_DATE}"
