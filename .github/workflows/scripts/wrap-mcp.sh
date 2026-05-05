#!/usr/bin/env bash
# Tee an MCP server's stderr to a log file while still exec'ing the real
# command — so when claude-code-action launches an MCP via npx and the
# server crashes during stdio handshake (or any other runtime reason),
# we capture the actual error message instead of silently losing it.
#
# The pre-warm step (see prewarm-qa-mcp.sh) catches the npx-install
# failure mode but cannot detect a server that installs fine yet
# crashes on boot — missing system libs, port conflict, browser-binary
# absent, MCP SDK version mismatch, etc. Without this wrapper those
# errors flow into claude-code-action's own logs (dense, frequently
# truncated) and never reach the user.
#
# Usage:
#   wrap-mcp.sh <log-path> <command> [args...]
#
# Behavior:
#   - stdin and stdout are pass-through (untouched) — these carry the
#     MCP JSON-RPC traffic between claude-code-action and the server.
#   - stderr is teed: copy goes to the log file, the original stderr is
#     still preserved so anything claude-code-action wants to surface
#     stays surfaced.
#   - We `exec` the target so signal handling and exit code propagate
#     correctly (the target replaces this script's process).

set -uo pipefail

if (( $# < 2 )); then
  echo "wrap-mcp.sh: usage: $0 <log-path> <command> [args...]" >&2
  exit 64  # EX_USAGE
fi

LOG_PATH="$1"
shift

mkdir -p "$(dirname "${LOG_PATH}")"

# Header line so multiple restarts within a single run are
# distinguishable in the log.
{
  printf '\n=== %s wrap-mcp launch: ' "$(date -u +%FT%TZ)"
  printf '%q ' "$@"
  printf '\n'
} >>"${LOG_PATH}" 2>/dev/null || true

# Process-substitution `>(...)` opens a FIFO; tee reads from it and
# duplicates to both the log file and the inherited stderr. Then
# `exec 2> >(...)` redirects this shell's stderr to that FIFO, and the
# subsequent `exec "$@"` replaces the shell with the MCP, inheriting
# the redirected fd 2.
exec 2> >(tee -a "${LOG_PATH}" >&2)
exec "$@"
