# User Privacy & Data Protection Review

## Objective

Deep-dive privacy audit ensuring user data is handled with care, minimized,
and protected throughout the codebase.

## ⚠️ Reporting Rules — Never Republish PII (read first)

This review writes findings into durable, broadly-visible artifacts (GitHub
issues, PR bodies, commit messages). On public repos those are world-readable.
A privacy audit must NOT itself leak the data it is auditing.

- **Never paste a literal PII or secret value** into a finding, comment, issue,
  or commit. This includes emails, names, phone numbers, IP addresses, physical
  addresses, government IDs, payment data, access tokens, API keys, passwords,
  and session identifiers — whether found in code, logs, fixtures, or seed data.
- **Reference location and field *type* only.** Say what kind of data leaks and
  where, not its value. For example write `user_email = <redacted email>` or
  "logs the customer's phone number at `auth.ts:42`" — never the actual string.
- **Do not open or quote the contents of likely-secret files** (`.env*`,
  credential stores, key files, database dumps, PII-laden fixtures/seed data).
  Report their presence and risk **by path only**; do not read their values into
  the transcript.
- If quoting a code line is necessary to explain a finding, **mask the data
  portion** before including it. When in doubt, redact.

These rules apply to every artifact this tool produces, including the fix-stage
PR description and commit messages.

## Review Checklist

### PII in Logs & Error Reports

- [ ] Production logs NEVER contain PII (emails, names, phone numbers, IPs)
- [ ] Error reporting (Sentry, etc.) does not include PII in breadcrumbs or extra data
- [ ] `console.log`, `console.warn`, `console.error` calls do not leak user data
- [ ] Stack traces sent to external services are scrubbed of PII
- [ ] If a logging utility exists with auto-redaction, it is used consistently

### Data Minimization

- [ ] Each data field collected from users has a clear, documented purpose
- [ ] No unnecessary data is stored (e.g., collecting location when not needed)
- [ ] Temporary data (OTP codes, verification tokens) has TTL/expiration
- [ ] Analytics events do not include identifying information beyond user ID

### Data Access Patterns

- [ ] Queries return only the fields the client actually needs
- [ ] User data is not leaked through:
  - Overly broad query results
  - Error messages that include other users' data
  - Debug endpoints or admin panels without proper access control
- [ ] Search results respect visibility/permission settings

### User Consent & Control

- [ ] Users can see what data is collected about them
- [ ] Data collection points have clear consent mechanisms
- [ ] Users have a path to delete their data (right to erasure)
- [ ] Third-party data sharing is explicit and requires user consent
- [ ] Users can export their data (right to portability)

### Third-Party Data Flows

- [ ] Identify every external service that receives user data:
  - Payment processors (Stripe, etc.)
  - Error reporting (Sentry, etc.)
  - Email services (Resend, SendGrid, etc.)
  - CDN/hosting (Cloudflare, AWS, etc.)
  - AI/ML services (OpenAI, Anthropic, etc.)
- [ ] Each third-party integration sends only the minimum necessary data
- [ ] Data processing agreements are in place (or flagged as needed)

### Frontend Privacy

- [ ] No PII in URL parameters or fragment identifiers
- [ ] Local storage / cookies do not contain unnecessary PII
- [ ] Third-party scripts (analytics, tracking) are identified and documented
- [ ] Meta tags and Open Graph data do not expose private user information
- [ ] Service workers and caches do not persist sensitive data unnecessarily

### Data Retention

- [ ] Identify any data that grows unboundedly without cleanup
- [ ] Soft-deleted data has a hard-delete schedule or process
- [ ] Session data, tokens, and temporary records have expiration
- [ ] Log retention policies are appropriate for the data sensitivity

## Severity Guide

- **CRITICAL**: PII in production logs, user data exposed to other users
- **HIGH**: Missing data deletion path, excessive data collection, PII in URLs
- **MEDIUM**: Missing consent mechanism, PII in error reports, overly broad queries
- **LOW**: Minor data minimization improvements, documentation gaps
