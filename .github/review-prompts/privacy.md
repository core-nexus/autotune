# User Privacy & Data Protection Review

## Objective

Deep-dive privacy audit ensuring user data is handled with care, minimized,
and protected throughout the codebase.

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

#### LLM / AI Services

When the codebase calls an LLM provider (Anthropic, OpenAI, etc.) directly or through an agent framework, audit the prompt construction and provider settings specifically:

- [ ] Prompts and tool-call inputs do not embed end-user PII (emails, names, addresses, phone numbers, payment details, government IDs) without explicit user consent for AI processing
- [ ] Provider account / workspace settings opt out of training on customer data where the provider supports it (e.g., zero-data-retention or no-training settings)
- [ ] Conversation transcripts, prompt logs, and completion logs (whether stored by the provider, in your own database, or in observability tooling) are not stored alongside identifying information unless required and disclosed
- [ ] The provider's DPA and sub-processor list cover the categories of data being passed in prompts; if the prompt contains regulated data (PHI, financial, EU personal data), confirm coverage
- [ ] System prompts, retrieved documents, and tool outputs do not silently leak data from other tenants/users into the prompt context

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
- [ ] CI/CD build logs and AI-tool transcripts (e.g. `claude-code-action` execution files, agent step logs, debug artifacts) do not persist PII or sensitive credentials beyond the runner; retention windows for Actions logs, artifacts, and any uploaded transcripts are configured appropriately for the data sensitivity

## Severity Guide

- **CRITICAL**: PII in production logs, user data exposed to other users
- **HIGH**: Missing data deletion path, excessive data collection, PII in URLs
- **MEDIUM**: Missing consent mechanism, PII in error reports, overly broad queries
- **LOW**: Minor data minimization improvements, documentation gaps
