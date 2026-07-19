#!/usr/bin/env bash
# Classify a PR's changed-file list as "docs-only" or "contains code".
#
# Reads changed filenames from stdin (one per line) and prints a single word:
#   true   → at least one file needs the full CI suite (lint/test/build/e2e)
#   false  → every changed file is documentation-only, so the suite can skip
#
# Use this to skip the expensive CI suite on docs-only PRs while STILL reporting
# the required status checks (a skipped-but-required job counts as passing, so
# the PR stays mergeable). See docs/ci-docs-only-skip.md for how to wire it in.
#
# Fail-safe by design: unknown extensions and an empty file list both resolve
# to `true` (run everything). We only skip when we are certain a file is docs.

set -euo pipefail

# A file is "docs-only" (safe to skip CI for) when it matches one of these
# patterns. Anything that does NOT match forces the full suite.
#
# NOTE: `case` globs match `/`, so `src/*.html` matches any depth under src/.
is_docs_only() {
  case "$1" in
    # HTML under a source directory (e.g. the app shell src/app.html, or a
    # framework error page) is real application code despite the .html
    # extension — never treat it as docs. Adjust "src/" to your source root.
    src/*.html) return 1 ;;
    *.md | *.txt | *.html) return 0 ;;
    doc/* | docs/*) return 0 ;;
    LICENSE | LICENSE.*) return 0 ;;
    *) return 1 ;;
  esac
}

saw_file=false
# `|| [ -n "$file" ]` processes a final line that lacks a trailing newline.
while IFS= read -r file || [ -n "$file" ]; do
  # Skip blank lines (trailing newline from the API/jq output).
  [ -z "$file" ] && continue
  saw_file=true
  if ! is_docs_only "$file"; then
    echo "true"
    exit 0
  fi
done

# No file forced the suite. If we saw at least one file, it was all docs → skip.
# If we saw none (empty input), fail safe and run everything.
if [ "$saw_file" = true ]; then
  echo "false"
else
  echo "true"
fi
