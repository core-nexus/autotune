# sentry-triage

Cloudflare Worker that receives Sentry webhooks, verifies them, and fires a
GitHub `repository_dispatch` against the configured target repo. The target
repo's `sentry-triage.yml` workflow then invokes Claude Code to open a fix PR.

The Worker is a thin bridge. It does not run Claude itself.

## What it does

1. Validates the incoming request (method, content-type, size, headers, HMAC
   signature, timestamp freshness).
2. Normalizes Sentry's two main webhook shapes (`event_alert`, `issue`) into a
   single `Normalized` payload.
3. Filters out noise: unknown projects, non-error levels (unless opted in),
   assigned/archived/ignored lifecycle events, recently-seen issues.
4. Fires `POST /repos/{owner}/{repo}/dispatches` with the normalized payload as
   `client_payload` (progressively shrunk to fit GitHub's 10 KB limit).
5. Records the dispatch in KV so a flapping alert rule cannot double-dispatch
   within 24 h. Regressions bypass dedup.

## HTTP surface

| Method | Path              | Purpose                                        |
| ------ | ----------------- | ---------------------------------------------- |
| `POST` | `/sentry/webhook` | Receive a Sentry Internal Integration webhook. |
| `GET`  | `/health`         | Liveness probe.                                |

Response body on `/sentry/webhook` is always a small JSON object:
`{ dispatchId, status, reason? }` where `status` is one of `dispatched`,
`filtered`, `deduped`, or `rejected`.

## Configuration

Secrets (`wrangler secret put <NAME>`):

- `SENTRY_CLIENT_SECRET` — from the Sentry Internal Integration.
- `PROJECT_MAP` — JSON string, Sentry project slug → `{ repo, eventType, minEventCount?, allowWarnings? }`.
- `GITHUB_PAT` — fine-grained PAT with `contents:write` + `actions:write` on all target repos.
- `SENTRY_DSN` — DSN for self-reporting exceptions (optional but recommended).

Vars (in `wrangler.toml` under `[vars]`):

- `LOG_LEVEL` — `debug`/`info`/`warn`/`error`. Default `info`.
- `REDACT_PII` — `true`/`false`. Default `true`. Strips `user.email` etc.
- `ALLOW_WARNINGS_GLOBAL` — `true`/`false`. Default `false`.

Bindings:

- `SENTRY_SEEN` (KV namespace) — dedup store with 24 h TTL. Create with
  `wrangler kv namespace create SENTRY_SEEN` and paste the id into `wrangler.toml`.
- `ANALYTICS` (Analytics Engine, optional) — counters.

Example `PROJECT_MAP`:

```json
{
  "frontend": {
    "repo": "acme/web",
    "eventType": "sentry-triage",
    "minEventCount": 1,
    "allowWarnings": false
  },
  "api": {
    "repo": "acme/api",
    "eventType": "sentry-triage"
  }
}
```

The keys are Sentry project slugs; the `repo` value is the GitHub
`owner/repo` to dispatch to. `eventType` defaults to `"sentry-triage"` and
must match the `repository_dispatch.types` entry in the target repo's
`.github/workflows/sentry-triage.yml`.

## Development

```
cd workers/sentry-triage
npm install
npm test            # unit tests, no internal mocks
npm run typecheck
npm run dev         # wrangler dev
```

Tests wire the real modules together and only stub `fetch` (the external
GitHub boundary) and the KV namespace (`FakeKV` in tests implements the same
contract the real binding exposes).

## Onboarding a new project

1. Add a new entry to `PROJECT_MAP` (Sentry project slug → target repo).
2. Deploy the Worker (`npm run deploy`).
3. In the target GitHub repo: drop in `.github/workflows/sentry-triage.yml`
   and set secrets (`CLAUDE_CODE_OAUTH_TOKEN`, `SENTRY_AUTH_TOKEN`).
4. In Sentry: create the Issue Alert rule pointing at the Worker URL
   (`https://<worker>.workers.dev/sentry/webhook`).
5. Fire a test event from Sentry's "Send test notification" button. Confirm
   the log line in the Worker, the dispatch on GitHub, and the resulting
   Actions run on the target repo.
