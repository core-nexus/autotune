# System Resilience Review

## Objective

Deep audit of operational resilience: how the system behaves when things go
wrong at a system level. Every external dependency can — and eventually will —
fail, rate-limit, slow down, or disappear. Every internal subsystem has a
saturation point. This review asks: **when the happy path breaks, does the
system degrade gracefully, or does it fall over?**

This is distinct from the `error-handling` review, which audits per-call-site
hygiene (catch blocks, error reporting, user feedback). Resilience is
**architectural**: rate limits, fallbacks, timeouts, idempotency, circuit
breakers, blast radius, and "what happens when X goes down" thought
experiments.

## Mental Model: The Chaos Questions

For every critical capability, answer these:

1. **What external services does it depend on?** (Payment provider, email
   provider, AI/LLM providers, media/image/video processing, object storage,
   observability/analytics, geo/location or maps APIs, auth/OAuth providers,
   and anything else reached over the network.)
2. **What happens to the user if each one is down for 5 minutes? 1 hour? 1
   day?** Is the failure visible and recoverable, or silent and corrupting?
3. **What are the documented rate limits?** Where's that number in code? What
   happens at 80% of the limit? At 100%? At 200%?
4. **Is there a fallback?** If so, is it actually wired up and tested — or is it
   aspirational?
5. **If traffic 10x'd overnight, what breaks first?** Is that failure mode
   contained, or does it cascade?
6. **Is the failure idempotent-safe?** Can we retry without corrupting data?

If the answer to any of these is "I don't know" or "it silently hangs", that's
a finding.

## Review Checklist

### External Service Inventory & Dependency Map

Grep the codebase for every network call to a non-local domain and build the
dependency list. For EACH third-party dependency, verify:

- [ ] Its failure mode is documented (even just in a code comment)
- [ ] Timeouts are explicitly configured — not relying on default HTTP-client
      timeouts (which can be infinity or minutes long)
- [ ] Retry policy is explicit: max attempts, backoff strategy, jitter
- [ ] Rate limits are documented in code near the call site, with a source link
      if possible
- [ ] There is a defined fallback or graceful degradation, OR an explicit note
      that this capability hard-fails by design
- [ ] The dependency's blast radius is understood — does its outage also take
      down unrelated features, or is the impact contained?

### Rate Limits (Ours To Them, Theirs To Us)

- [ ] **Outbound rate limits**: For every external API we call, is there
      client-side throttling to stay under the provider's rate limit even under
      burst traffic? (Thundering-herd scenarios: a scheduled job, a webhook
      replay, a mass signup.)
- [ ] **Inbound rate limits**: Do our own public surfaces have rate limits?
  - Expensive or spam-prone mutations/actions (signup, invite, share, report)
  - Publicly exposed HTTP endpoints
  - Auth flows (login, magic link, password reset) — brute-force protection
- [ ] **Per-user quotas**:
  - Are quotas enforced server-side (never only client-side)?
  - Can they be bypassed by creating multiple accounts, or by racing
    concurrent requests before the counter increments?
  - Does exhausting a quota return a distinguishable error (e.g. a
    `RATE_LIMITED` code) or a generic 500?
- [ ] **Cost caps**: Is there a circuit breaker that stops expensive operations
      (AI generation, media generation) if daily/monthly spend crosses a
      threshold? A runaway bug should not produce a runaway bill.

### Retry, Backoff, and Idempotency

- [ ] **Retries use exponential backoff with jitter**, not fixed delays. Fixed
      delays produce thundering herds when many clients retry in sync.
- [ ] **Retries are bounded** — no infinite retry loops. Eventually, give up and
      surface the failure.
- [ ] **Retries only apply to idempotent operations**. Retrying a
      non-idempotent call (charge, send email, send push) can duplicate work.
- [ ] **Webhook handlers are idempotent**: providers redeliver webhooks on
      failure. Handlers must detect duplicates (via event ID or similar) and
      no-op, not double-charge / double-email / double-grant.
- [ ] **Mutations that spend credits / grant entitlements** are guarded against
      double-execution — idempotency keys or transaction-level checks.

### Timeouts Everywhere

- [ ] **Every outbound network call** has a timeout / abort signal. A hung
      third-party API should not hold a server request open until its own
      execution limit.
- [ ] **Every long-running task** has an internal deadline and degrades
      gracefully as it approaches it, rather than being killed by the platform.
- [ ] **Every frontend async operation** has a timeout with user-visible
      feedback. The UI must not spin forever if a request never resolves.
- [ ] **Live-connection reconnection**: when a realtime/WebSocket connection
      drops, does the UI show a "reconnecting" state and resume cleanly?

### Graceful Degradation & Fallbacks

For each non-critical capability, confirm it degrades instead of breaking the
whole page/flow:

- [ ] **AI/enhancement layer fails** → core create/save still works, the layer
      is marked unavailable, the user can retry
- [ ] **Media/image upload fails** → clear error to the user, form state
      preserved, no lost work
- [ ] **Email send fails** → the operation continues where possible, failure is
      queued for retry, the user is warned if the email was essential (e.g.
      magic-link login)
- [ ] **Analytics / observability fails** → zero user-visible impact; we NEVER
      block a user-facing operation on an observability call
- [ ] **Geo/location lookup fails** (if present) → the user can still save with
      a manually entered or empty location; location-dependent UI shows a
      fallback rather than a crash
- [ ] **Realtime subscription temporarily disconnected** → UI shows stale data
      rather than an empty state; writes queue or clearly fail
- [ ] **Payment provider down at checkout** → clear, retryable error message;
      cart/session state preserved
- [ ] **Feature-flag lookup unavailable** → code defaults to a known-safe
      behavior; never crashes because a flag lookup failed

### Critical Path Identification

- [ ] Is there a clear, documented list of **critical-path capabilities**
      (signup, login, primary create/save, main feed load) vs **nice-to-have
      capabilities** (AI enhancement, recommendations, analytics)?
- [ ] **Critical path should depend on as few external services as possible.** A
      login flow that depends on the payment provider is a scaling risk.
- [ ] **Nice-to-have capabilities must fail independently** of critical ones. A
      broken recommendation engine must not break the feed.

### Cascading Failure Prevention

- [ ] **One slow dependency does not block unrelated code paths.** A slow
      third-party call in one action should not consume the whole concurrency
      budget for other actions.
- [ ] **Retries do not amplify outages.** When a provider is down, our retry
      logic + client retry logic + user retry should not combine into a DDoS of
      the recovering provider. Use circuit breakers or backoff to shed load.
- [ ] **Write hot-spots** (global counters, popular documents) have been
      identified and sharded or moved to eventual consistency.
- [ ] **Queue / scheduler backlog**: scheduled and background jobs have a
      bounded work rate. A backlog should not explode into a spike when the
      service recovers.

### Bulk / Batch Safety

- [ ] **Batch operations degrade per-item**: if one item in a 1000-item job
      fails, the other 999 still complete, and the failure is reported without
      aborting the batch.
- [ ] **Large reads are paginated** — never "load all" of a growing table.
- [ ] **Large writes are chunked** — stay within the platform's transaction
      read/write limits at the projected 10x and 100x data size.

### State Recovery & Self-Healing

- [ ] **Partial writes can be detected and reconciled.** Example: a charge
      succeeds at the payment provider but the matching local write fails — is
      there a reconciliation path? A periodic sweep? An event-driven heal?
- [ ] **Stuck states have a recovery mechanism.** Records in "pending",
      "processing", or "uploading" states that never complete should either
      time out, be retried, or be surfaced for manual intervention.
- [ ] **Orphaned resources are cleaned up.** Uploaded-but-unattached files,
      abandoned checkouts, half-created records — is there a sweep?

### Resource Exhaustion

- [ ] **Memory growth is bounded** in long-lived code paths (client sessions,
      global stores, event subscriptions).
- [ ] **Connection / subscription counts per user have a cap.** A single buggy
      client must not be able to open unlimited live subscriptions.
- [ ] **File / upload sizes are enforced server-side** — not just in the UI — to
      prevent memory/storage exhaustion.
- [ ] **Query result sizes are capped** — no endpoint can be coaxed into
      returning a multi-megabyte payload.

### Observability for Resilience

- [ ] **External service failures are reported** with tags that allow filtering
      by service (e.g. `service=payments`, `service=media`).
- [ ] **Latency to external services is measured** so degradation is visible
      before it becomes an outage.
- [ ] **Retries and rate-limit errors are logged as a distinct class** from
      outright failures, so a rising retry rate signals an incoming problem.
- [ ] **Alerts exist** for critical background-job failures.

### Kill Switches & Config Safety

- [ ] **Risky or expensive features can be turned off quickly** (env var / remote
      config / feature flag) without a redeploy.
- [ ] **Default configuration is safe**: if a config lookup fails or a value is
      missing, the feature defaults to the safer of {on, off} — usually off for
      expensive/spammy features, on for critical UX.
- [ ] **No code path silently disables safety** when an env var is missing (e.g.
      rate limiting that only works if a secret is set should log a clear
      warning or refuse to start, not silently become a no-op).

### Chaos Thought Experiments

For each of the following scenarios, answer "what does the user see?" and "what
data is lost?":

- [ ] The backend returns 503 for 60 seconds during peak traffic
- [ ] A payment webhook endpoint is DOWN when the provider tries to deliver an
      event
- [ ] An AI/LLM provider rate-limits us for 10 minutes during a promotional
      launch
- [ ] The image/media service returns 500 while users are uploading avatars
- [ ] The email provider is degraded and magic-link emails take 5 minutes to
      arrive
- [ ] A geo/location-search API returns empty results for every query
- [ ] A runaway job tries to send 10,000 emails in one minute
- [ ] A user double-clicks "purchase" and the frontend fires two mutations
      before the first resolves
- [ ] The same payment webhook is delivered twice
- [ ] A subscription-renewal webhook arrives for a user whose record was already
      deleted
- [ ] A background job that normally processes 100 items per hour suddenly has a
      backlog of 50,000

Every scenario should have a defined, sensible answer. "We'd find out when users
complain" is a finding.

## Severity Guide

- **CRITICAL** — Missing idempotency on a money-handling webhook or entitlement
  grant that can double-charge or double-grant; a cost runaway with no per-user
  or global cap on expensive generation
- **HIGH** — Missing timeout or retry on a critical-path integration; silent
  data loss on external failure; unbounded retry that could amplify an outage;
  missing rate limit on an expensive/spammy endpoint; single-point-of-failure in
  the critical path with no fallback plan
- **MEDIUM** — Non-critical feature with no graceful degradation (breaks the
  page on third-party failure); missing jitter on retries; missing pagination on
  a growing list; observability gap that would delay detection of an outage;
  batch job that aborts on single-item failure
- **LOW** — Minor timeout tuning; clearer error messages for degraded states;
  additional failure tags; reconciliation-sweep improvements; documentation of
  resilience posture

## Scope Reminder

This review is about **architectural resilience**, not catch-block hygiene. If
you find a bare `catch {}` that silences an error, note it but treat it as a
pointer to the `error-handling` review rather than the main focus. Concentrate
the body of your findings on: rate limits, timeouts, fallbacks, idempotency,
cascade prevention, and "what happens when X goes down".
