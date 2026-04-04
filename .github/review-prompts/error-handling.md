# Error Handling & Resilience Review

## Objective

Audit the codebase for proper error handling. Every error must be reported,
every failure must be visible, and no bug should hide in a silent catch block.

The core principle: **"If this fails in production, will we find out?"**

## Review Checklist

### Silent Error Suppression (The Cardinal Sin)

Search the ENTIRE codebase for these anti-patterns and flag every instance:

- [ ] `catch (_e) { }` or `catch (e) { }` with empty body
- [ ] `.catch(() => {})` or `.catch(() => undefined)`
- [ ] `catch` blocks that only `console.warn` without throwing or reporting
- [ ] `catch` blocks that return `null`/`undefined` without reporting the error
- [ ] `try/catch` around code that should be allowed to throw

### Backend Error Handling

- [ ] Prefer throwing over catching — let the framework's error reporting catch
      unhandled errors automatically
- [ ] When catching is necessary:
  - Log the error with context (function name, parameters, user ID)
  - Either re-throw OR return an explicit error result
- [ ] Structured error types for client-distinguishable errors
  (e.g., `INSUFFICIENT_CREDITS`, `RATE_LIMITED`, `NOT_FOUND`)
- [ ] No `console.log` for errors — use proper error reporting
- [ ] `console.warn` is ONLY for non-error conditions (disabled features, etc.)
- [ ] Scheduled functions and cron jobs have proper error reporting
- [ ] Server actions that call external APIs report failures clearly

### Frontend Error Handling

- [ ] Error reporting service (Sentry, etc.) is called for all caught errors
  - Even when recovering gracefully, report to the error service
- [ ] User-facing errors show appropriate feedback (toast, error boundary, etc.)
- [ ] Failed API calls are NEVER silently swallowed
- [ ] Error boundaries exist for critical UI sections
- [ ] Network failures show appropriate user feedback
- [ ] Loading states handle the error → loaded → error cycle correctly

### Promise Handling

- [ ] No floating promises (every Promise is awaited, returned, or explicitly voided)
- [ ] `Promise.all` / `Promise.allSettled` usage handles individual rejections
- [ ] Async event handlers properly catch and report errors
- [ ] Reactive/computed values with async operations handle errors

### Error Context & Debugging

- [ ] Error messages include enough context to diagnose the issue:
  - What operation was attempted
  - What input was provided (without PII)
  - What the expected outcome was
- [ ] Stack traces are preserved when re-throwing
- [ ] Error tracking tags/context are set for important error categories

### Resilience Patterns

- [ ] External API calls have:
  - Appropriate timeout configuration
  - Retry logic where idempotent
  - Circuit breaker or backoff patterns where appropriate
- [ ] Webhook handlers are idempotent (safe to retry)
- [ ] Rate limiting returns clear error responses, not silent drops
- [ ] Graceful degradation: if a non-critical feature fails, the rest works

### CI/CD Failure Visibility

- [ ] All scheduled (cron) CI workflows notify the team on failure
- [ ] Push-to-main workflows notify on failure (not just PR checks)
- [ ] Background jobs that can fail without anyone noticing have alerting

## Anti-Patterns to Fix

1. **The Silencer**: `catch () {}` — Fix: report + rethrow or return error
2. **The Logger**: `catch (e) { console.warn(e) }` — Fix: use error reporting + rethrow
3. **The Swallower**: `.catch(() => null)` — Fix: report + handle explicitly
4. **The Hider**: `try { ... } catch { return defaultValue }` — Fix: at minimum report
5. **The Optimist**: No error handling at all on external calls — Fix: add proper handling

## Severity Guide

- **CRITICAL**: Silent catch hiding security or data-loss errors
- **HIGH**: Backend functions without error reporting, user-facing failures with no feedback
- **MEDIUM**: Missing error context, incomplete error messages, missing retries
- **LOW**: Verbose error handling that could be simplified, minor context improvements
